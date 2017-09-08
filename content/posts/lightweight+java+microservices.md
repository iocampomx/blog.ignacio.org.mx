+++
title = "Lightweight (Guice) Secure (JWT) Java RESTful (JAX-RS) Microservices"
tags = ["microservices", "java", "jax-rs", "jetty", "jwt", "guice"]
date = "2017-07-28"
draft = "True"
+++

## Context
You are developing RESTful microservices based web applications.

## Problem
Define a stack of technologies suitable to develop lightweight and secure microservice based web applications, built on top of well known standards and technologies widely supported by the open source community.

<!--more-->

## Forces
* You want to be able to deploy your microservices almost anywhere (private cloud, on-premise servers, docker containers, Raspberry PI, linux, windows, etc).
* You want to be able to secure your microservices with JWT and secure your endpoints with roles.
* You want to be able to switch/improve/customize the way in which you're securing your application easily (ContainerRequestFilter).
* You want to use a Dependency Injection framework to decouple your dependencies.

## Solution

Create a maven based project as guideline (I will publish another post about how to create Maven artifacts) of your microservices web applications using the following technologies / libraries:

### Libraries

|Name|Description (Obtained from their respective websites)|
|---|---|
|[Golge Guice][1]|A lightweight dependency injection framework for Java 6 and above|
|[Jetty Servlet Container][2]|A Web server and javax.servlet container|
|[Apache CXF JAX-RS (cxf-rt-frontend-jaxrs)][cxf-jax-rs]|Java API for RESTful Web Services implementation, supports the Java API for RESTful Web Services: JAX-RS 2.0 [(JSR-339)][JSR-339] and JAX-RS 1.1 [(JSR-311)][JSR-311].|
|[jackson-jaxrs-json-provider][jackson-jaxrs-providers]|Multi-module project that contains Jackson-based JAX-RS providers for JSON, XML, YAML, Smile, CBOR formats|
|**Security**|
|[JJWT][jjwt]|Java JWT: JSON Web Token for Java and Android|
|**Log**|
|[Simple Logging Facade for Java (SLF4J)][slf4j]|Serves as a simple facade or abstraction for various logging frameworks (e.g. java.util.logging, logback, log4j) allowing the end user to plug in the desired logging framework at deployment time.|
|[logback-classic][logback]|Logback is intended as a successor to the popular log4j project, [picking up where log4j leaves off][reasonsToSwitch].|
|**Testing**|
|[JUnit][junit]|JUnit is a simple framework to write repeatable tests. It is an instance of the xUnit architecture for unit testing frameworks.|
|[Apache CXF JAX-RS Client API (cxf-rt-rs-client)][cxf-rt-rs-client]|Implements JAX-RS Client API.|
|[system-rules]|System Rules is a collection of JUnit rules for testing code which uses java.lang.System.|

### References
* https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/index.html

[1]: https://github.com/google/guice
[2]: http://www.eclipse.org/jetty/
[cxf-jax-rs]: http://cxf.apache.org/docs/jax-rs.html
[JSR-339]: http://jcp.org/en/jsr/detail?id=339
[JSR-311]: http://jcp.org/en/jsr/detail?id=311
[jackson-jaxrs-providers]: https://github.com/FasterXML/jackson-jaxrs-providers
[jjwt]: https://github.com/jwtk/jjwt
[slf4j]: https://www.slf4j.org/
[logback]: https://logback.qos.ch/
[reasonsToSwitch]: https://logback.qos.ch/reasonsToSwitch.html
[junit]: http://junit.org/junit4/
[cxf-rt-rs-client]: http://cxf.apache.org/docs/jax-rs-client-api.html
[system-rules]: https://github.com/stefanbirkner/system-rules


