+++
title = "Jenkinsfile: Microservices Continuous Integration/Delivery with Jenkins, Kubernetes & fabric8"
tags = ["microservices", "jenkins", "ci", "kubernetes", "fabric8"]
date = "2017-09-08"
draft = "False"
+++

In this example I'm going to show how to define a [**Jenkinsfile**](https://jenkins.io/doc/book/pipeline/jenkinsfile/) using the [Scripted format](https://jenkins.io/doc/book/pipeline/syntax/#scripted-pipeline) (a domain-specific language based on Groovy). This example only consider the "dev" environment, I have plans to update this post in the future with other environments.

If you want to understand more about what Continuous Integration is and how it does work, visit [this article from Martin Fowler](https://martinfowler.com/articles/continuousIntegration.html).

Before start, I will define the context in which I'm using this Jenkinsfile to give you more visibility about the utiliness of it:

This **Jenkinsfile** is part of a Maven Archetype that I’m using to develop microservices, this way I ensure consistency across projects, thats why you will see some ${variables} that are being replaced at the moment of the creation of the project based on the artifact.

For a complete reference of Jenkins steps, visit this page: https://jenkins.io/doc/pipeline/steps/

<style type="text/css">
	#nacho .vglnk {
		color: #FFF !important;
	}
</style>

<pre>
<code id="nacho">
node {
	// 1
    try {
    	// 2
        stage('SCM checkout')
        checkout scm
        def lastCommit = sh(returnStdout: true, script: '(git log -1|grep "maven-release-plugin") || true').trim()
        if(lastCommit) {
            currentBuild.result = 'SUCCESS'
            echo 'Detected commit from maven-release-plugin, marking this build as a success and stopping the pipeline...'
            return
        }

		// 3
        stage('Validate NCP environment')
        sh "ncp-validate"

		// 4
        stage('Compile')
        sh 'mvn -B clean compile'

		// 5
        stage('Tests')
        sh 'mvn -B test'

		// 6
        stage('Package (Install)')
        sh 'mvn -B install fabric8:resource fabric8:build -DskipTests'

        withCredentials([usernamePassword(credentialsId: 'depusr-nafiux-${artifactId}', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {

			// 7
            stage('Push to ECR')
            sh 'mvn -B fabric8:push'

			// 8
            stage('Deploy dev: Cloudformation')
            sh "(aws cloudformation deploy --region us-east-1 --template-file cloudformation.json --stack-name cf-nafiux-${artifactId}-dev --parameter-overrides Env=dev) || true"
        }

		// 9
        stage('Deploy dev: Docker microservice')
        sh 'mvn -B fabric8:apply'

		// 10
        stage('Integration tests')
        sh 'mvn -B verify -DskipUTs -DsvcEndpoint=https://svc.dev.apps.foo.bar -Djavax.net.ssl.trustStore=`pwd`/${artifactId}-it/src/test/resources/test-dev.keystore'

		// 11
        stage('Release')
        sh 'mvn -B release:prepare release:perform -Darguments="-DskipTests"'

		// 12
        slackSend color: "#00FF00", message: "Build finished: http://ci.foo.net/job/${env.JOB_NAME}/${env.BUILD_NUMBER}\nHealthcheck: https://svc.dev.apps.foo.bar/api/${shortName}/v1/healthcheck"

    } catch (e) {

    	//13
        slackSend color: "#FF0000", message: "Build failed: http://ci.foo.net/job/${env.JOB_NAME}/${env.BUILD_NUMBER}/console ${e.message}"
        error(e.message)
    }
}
</code>
</pre>

Lets review each point in detail:

## 1. Try block

It's the typical try/catch syntax for Java/Groovy, with this approach, even though an exception could be raised in any part of the Jenkinsfile, I can catch it to do something meaninful with it, as you will see later.

## 2. SCM checkout

This step performs the checkout of the repo.

Additionally, I validate if the last commit contains the "maven-release-plugin" string in any part, if so, I set the result as **SUCCESS** `currentBuild.result = 'SUCCESS'` and to stop the pipeline `return`.

This isn't the most elegant way to handle this, but, even though Jenkins does have the option to **ignore commit based on certain criterias**, there is an unresolved bug ([JENKINS-36195](https://issues.jenkins-ci.org/browse/JENKINS-36195?page=com.atlassian.jira.plugin.system.issuetabpanels%3Aall-tabpanel)) reported on Jenkins

![Jenkins Bug](/posts/jenkinsfile/jenkins-bug.png)

(Option present in the UI but not working)

## 3. Validate environment

This step executes a bash script I have created to ensure the environment does have the right versions of tools such as java, awscli, docker, maven, git, npm, etc., I’m using this script also in my laptop to avoid potential incompatibility problems with thinks like `yum update` or `brew update`.

Any small change in any version will cause a non-zero exit return code, which will causes the pipeline to fail.

The script is available in the global path, so that I can call it wherever I'm, it is versionated and it does have an auto update feature each time it being called (git pull & restart if changes) to keep it up-to-date all time.

[![ncp-validate](/posts/jenkinsfile/ncp-validate.png)](/posts/jenkinsfile/ncp-validate.png)

You can download a copy of the script [here](/posts/jenkinsfile/ncp-validate.txt), it has been tested in Linux & Mac.

## 4, 5. Compile & Tests

`sh 'mvn -B clean compile'` & `sh 'mvn -B test'`

Starting from this step, I basically executes the basic Maven's phases http://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html. **-B** option is for: `Run in non-interactive (batch) mode (disables output color)`.

## 6. Package (Install)

`sh 'mvn -B install fabric8:resource fabric8:build -DskipTests'`

The **install** phase go thru all the previous phases (validate, compile, test, package, verify) and install your project in your local maven repositor (~/.m2/repository), because of that, I specify `-DskipTests` to not re-run the tests that have been executed in the previous step.

The **fabric8** goals are related to the [fabric8-maven-plugin](https://github.com/fabric8io/fabric8-maven-plugin), a Maven plugin for getting your Java apps on to Kubernetes and OpenShift:

  * [fabric8:resource](https://maven.fabric8.io/#fabric8:resource) - Create Kubernetes and OpenShift resource descriptors (.yml files).
  * [fabric8:build](https://maven.fabric8.io/#fabric8:build) - Build Docker images

I will use the yaml descriptor file and the docker image later to deploy the microservice to the cluster.

## 7. Push to ECR

`sh 'mvn -B fabric8:push'` [fabric8:push](https://maven.fabric8.io/#fabric8:push) - Push Docker images to a registry.

## 8. Run Cloudformation template

`sh "(aws cloudformation deploy --region us-east-1 --template-file cloudformation.json --stack-name cf-nafiux-${artifactId}-dev --parameter-overrides Env=dev) || true"`

**WARNING:** This command should be refactorized since it always return a zero exit code because of the `or true` expression at the end, this should be modified and let awscli cause an exception if something goes wrong with cloudformation. I added `or true` at the end because `aws cloudformation` return a non-zero exit code if the template didn't change.

## 9. Deploy microservice

`sh 'mvn -B fabric8:apply'` [fabric8:apply](https://maven.fabric8.io/#fabric8:apply) - This goal applies the resources created with fabric8:resource to a connected Kubernetes or OpenShift cluster.

## 10. Integration tests

`sh 'mvn -B verify -DskipUTs -DsvcEndpoint=https://svc.dev.apps.foo.bar -Djavax.net.ssl.trustStore=`pwd`/${artifactId}-it/src/test/resources/test-dev.keystore'`

You may ask why you don't see any explicit goal related to **test**, that is because I'm using [maven-failsafe-plugin](http://maven.apache.org/surefire/maven-failsafe-plugin/), which is designed to run integration tests.

A note from the official documentation:

> when running integration tests, you should invoke Maven with the (shorter to type too)

`mvn verify`, rather than trying to invoke the `integration-test` phase directly, as otherwise the `post-integration-test` phase will not be executed.

The `-DskipUTs` it's a property that I'm using with `maven-surefire-plugin` to know when I don't should execute the unit tests:

	<plugin>
	    <groupId>org.apache.maven.plugins</groupId>
	    <artifactId>maven-surefire-plugin</artifactId>
	    <version>2.20</version>
	    <configuration>
	        <skipTests>${skipUTs}</skipTests>
	    </configuration>
	</plugin>

Finally, the `-DsvcEndpoint` and `-Djavax.net.ssl.trustStore` are other properties that I'm using inside the integration tests.

## 11. Release

`sh 'mvn -B release:prepare release:perform -Darguments="-DskipTests"'`

These goals are related to the [maven-release-plugin](http://maven.apache.org/maven-release/maven-release-plugin/).

I prefer to perform the release goal only if everything it's ok.

## 12, 13. Success & Failute Slack notification

The try/catch block does possible to execute one of the two depending on the case.

Success:

`slackSend color: "#00FF00", message: "Build finished: http://ci.foo.net/job/${env.JOB_NAME}/${env.BUILD_NUMBER}\nHealthcheck: https://svc.dev.apps.foo.bar/api/${shortName}/v1/healthcheck"`

Failure:

`slackSend color: "#FF0000", message: "Build failed: http://ci.foo.net/job/${env.JOB_NAME}/${env.BUILD_NUMBER}/console ${e.message}"`

![Slack notification](/posts/jenkinsfile/slack-notification.png)

# Jenkins - Stage view

![Stage view](/posts/jenkinsfile/jenkins-pipeline.png)
