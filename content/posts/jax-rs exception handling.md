+++
title = "JAX-RS Exception Handling"
tags = ["microservices", "java", "jax-rs", "exceptions"]
date = "2017-08-07"
+++

# Exception handling

Exceptions are in general very useful, they help you to understand what could go wrong or what was wrong.

When you are developing web services, if you propagate exceptions properly, they could help you to reduce the number of request from developers using your API asking help or support, by implementing meaningful responses, i.e., the proper implementation of HTTP status codes and providing as much information as possible in the response.

## Customer facing exceptions

You must split your errors in two categories:

  * **Client errors**  (400-series HTTP response code) - Tell the client that a fault has taken place on __their side__. They should not re-transmit the same request again, but fix the error first.
  * **Server errors**  (500-series HTTP response code) - Tell the client the server failed to fulfill an apparently valid request. The client can continue and try again with the request without modification.

Whenever if possible, you should use exceptions classes already defined in [javax.ws.rs](https://jax-rs.github.io/apidocs/2.0/javax/ws/rs/package-frame.html) package that are related to HTTP response codes.

In order to provide a better experience to the final user/developer, I suggest to create an **ExceptionMapper** to intercept **WebApplicationException** based exceptions to include the exception message in the response to the user request:

<pre>
<code class="language-java">
package com.nafiux.ncp.base.exception;

import org.apache.cxf.jaxrs.utils.JAXRSUtils;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;
import javax.ws.rs.ext.ExceptionMapper;
import javax.ws.rs.ext.Provider;

@Provider
public class WebApplicationExceptionMapperProvider implements ExceptionMapper&lt;WebApplicationException&gt; {

  class ErrorMessage {
    int status;
    String message;
    String developerMessage;

    public ErrorMessage(int status, String message) {
      this.status = status;
      String[] messages = message.split("\\|");
      this.message = messages[0];
      if(messages.length > 1) {
        this.developerMessage = messages[1];
      }
    }

    public int getStatus() { return this.status; }
    public String getMessage() { return this.message; }
    public String getDeveloperMessage() { return this.developerMessage; }
  }

  public Response toResponse(WebApplicationException ex) {
    Response exResponse = ex.getResponse();
    ErrorMessage errorMessage = new ErrorMessage(exResponse.getStatus(), ex.getMessage());
    return JAXRSUtils.fromResponse(ex.getResponse()).entity(errorMessage).build();
  }

}
</code>
</pre>

In the previous example, **WebApplicationExceptionMapperProvider** expect a `pipe (|)` as a separator in the exception message to split it in two kind of messages, the first part is a high level error message final user oriented, the second part is a more detailed error message developer oriented (upon each specific exception raised, if no pipe is provided, **developerMessage** isn't included in the response).

Example:

<pre>
<code class="language-java">

throw new ForbiddenException("Invalid username or password|Validate that you're sending the 'username' and 'password' in the payload");

</code>
</pre>

If you need to define your custom exceptions that doesn't extend from **WebApplicationException**, you should create also your own [ExceptionMapper](https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/part1/chapter7/exception_handling.html#exception-mapping) for that exception/s, so that you can provide the same level of detail in the response to the user.

Without **WebApplicationExceptionMapperProvider** (Apache CXF has an [WebApplicationExceptionMapper](https://github.com/apache/cxf/blob/master/rt/frontend/jaxrs/src/main/java/org/apache/cxf/jaxrs/impl/WebApplicationExceptionMapper.java) already defined and used by default, but it doesn't include the exception message in the response to the user/developer):

<pre>
<code class="language-bash">
ignacio.ocampo@MXTI1-4WQG8WQ ~ $ curl -i -X POST -H "Content-Type: application/json" http://localhost:8080/api/uaa/svc/public/v1/auth/login -d '{"username": "invalid@user.com", "password": "changeme"}' && echo ""
HTTP/1.1 403 Forbidden
Date: Sun, 06 Aug 2017 21:03:11 GMT
Content-Length: 0
Server: Jetty(9.4.6.v20170531)

</code>
</pre>

With **WebApplicationExceptionMapperProvider** (the example class described above):

<pre>
<code class="language-bash">
ignacio.ocampo@MXTI1-4WQG8WQ ~ $ curl -i -X POST -H "Content-Type: application/json" http://localhost:8080/api/uaa/svc/public/v1/auth/login -d '{"username": "invalid@user.com", "password": "changeme"}' && echo ""
HTTP/1.1 403 Forbidden
Date: Sun, 06 Aug 2017 21:03:36 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Server: Jetty(9.4.6.v20170531)

{"status":403,"message":"Invalid username or password","developerMessage":"Validate that you're sending the 'username' and 'password' in the payload"}

</code>
</pre>

## Internal exceptions

By internal exceptions I mean all exceptions (in the server side obviously).

We must ensure that all exceptions are being "converted" to a customer facing exceptions, there are two ways (see more above):

  - Catch those exceptions at some point in the api implementation layer and convert them in a **WebApplicationException**.
  - Register a ExceptionMapper for that exception, so that you can provide the same level of detail in the response to the user.

You should have in mind that there could be some hidden **RuntimeExceptions** (unchecked) that you won't see until they appears, specially when you're using third part libraries, e.g.:

    @POST
    @Path("/login")
    @Produces(MediaType.APPLICATION_JSON)
    public Response postLogin(LoginInput login) {
      throw new DynamoDBMappingException("This is an example");
    }

**DynamoDBMappingException** extends from **RuntimeException** (unchecked), if you invoke the method, you will receive:

<pre style="max-height: 400px">
ignacio.ocampo@MXTI1-4WQG8WQ ~ $ curl -i -X POST -H "Content-Type: application/json" http://localhost:8080/api/uaa/svc/public/v1/auth/login -d '{"username": "invalid@user.com", "password": "changeme"}' && echo ""
HTTP/1.1 500 Server Error
Cache-Control: must-revalidate,no-cache,no-store
Content-Type: text/html;charset=iso-8859-1
Content-Length: 4418
Connection: close
Server: Jetty(9.4.6.v20170531)

&lt;html&gt;
&lt;head&gt;
&lt;meta http-equiv="Content-Type" content="text/html;charset=utf-8"/&gt;
&lt;title>Error 500 Server Error&lt;/title&gt;
&lt;/head&gt;
&lt;body&gt;&lt;h2&gt;HTTP ERROR 500&lt;/h2&gt;
&lt;p&gt;Problem accessing /api/uaa/svc/public/v1/auth/login. Reason:
&lt;pre&gt;    Server Error&lt;/pre&gt;&lt;/p&gt;&lt;h3&gt;Caused by:&lt;/h3&gt;&lt;pre&gt;com.amazonaws.services.dynamodbv2.datamodeling.DynamoDBMappingException: This is an example
  at com.nafiux.ncp.uaa.application.UAAAplicationImpl.postLogin(UAAAplicationImpl.java:42)
  at com.nafiux.ncp.uaa.api.v1.auth.AuthenticationApiImpl.postLogin(AuthenticationApiImpl.java:15)
  at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
  at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
  at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
  at java.lang.reflect.Method.invoke(Method.java:497)
  at org.apache.cxf.service.invoker.AbstractInvoker.performInvocation(AbstractInvoker.java:180)
  at org.apache.cxf.service.invoker.AbstractInvoker.invoke(AbstractInvoker.java:96)
  at org.apache.cxf.jaxrs.JAXRSInvoker.invoke(JAXRSInvoker.java:189)
  at org.apache.cxf.jaxrs.JAXRSInvoker.invoke(JAXRSInvoker.java:99)
  at org.apache.cxf.interceptor.ServiceInvokerInterceptor$1.run(ServiceInvokerInterceptor.java:59)
  at org.apache.cxf.interceptor.ServiceInvokerInterceptor.handleMessage(ServiceInvokerInterceptor.java:96)
  at org.apache.cxf.phase.PhaseInterceptorChain.doIntercept(PhaseInterceptorChain.java:308)
  at org.apache.cxf.transport.ChainInitiationObserver.onMessage(ChainInitiationObserver.java:121)
  at org.apache.cxf.transport.http.AbstractHTTPDestination.invoke(AbstractHTTPDestination.java:262)
  at org.apache.cxf.transport.servlet.ServletController.invokeDestination(ServletController.java:234)
  at org.apache.cxf.transport.servlet.ServletController.invoke(ServletController.java:208)
  at org.apache.cxf.transport.servlet.ServletController.invoke(ServletController.java:160)
  at org.apache.cxf.transport.servlet.CXFNonSpringServlet.invoke(CXFNonSpringServlet.java:180)
  at org.apache.cxf.transport.servlet.AbstractHTTPServlet.handleRequest(AbstractHTTPServlet.java:299)
  at org.apache.cxf.transport.servlet.AbstractHTTPServlet.doPost(AbstractHTTPServlet.java:218)
  at javax.servlet.http.HttpServlet.service(HttpServlet.java:707)
  at org.apache.cxf.transport.servlet.AbstractHTTPServlet.service(AbstractHTTPServlet.java:274)
  at org.eclipse.jetty.servlet.ServletHolder.handle(ServletHolder.java:841)
  at org.eclipse.jetty.servlet.ServletHandler.doHandle(ServletHandler.java:535)
  at org.eclipse.jetty.server.handler.ScopedHandler.nextHandle(ScopedHandler.java:188)
  at org.eclipse.jetty.server.handler.ContextHandler.doHandle(ContextHandler.java:1253)
  at org.eclipse.jetty.server.handler.ScopedHandler.nextScope(ScopedHandler.java:168)
  at org.eclipse.jetty.servlet.ServletHandler.doScope(ServletHandler.java:473)
  at org.eclipse.jetty.server.handler.ScopedHandler.nextScope(ScopedHandler.java:166)
  at org.eclipse.jetty.server.handler.ContextHandler.doScope(ContextHandler.java:1155)
  at org.eclipse.jetty.server.handler.ScopedHandler.handle(ScopedHandler.java:141)
  at org.eclipse.jetty.server.handler.HandlerCollection.handle(HandlerCollection.java:126)
  at org.eclipse.jetty.server.handler.HandlerWrapper.handle(HandlerWrapper.java:132)
  at org.eclipse.jetty.server.Server.handle(Server.java:564)
  at org.eclipse.jetty.server.HttpChannel.handle(HttpChannel.java:317)
  at org.eclipse.jetty.server.HttpConnection.onFillable(HttpConnection.java:251)
  at org.eclipse.jetty.io.AbstractConnection$ReadCallback.succeeded(AbstractConnection.java:279)
  at org.eclipse.jetty.io.FillInterest.fillable(FillInterest.java:110)
  at org.eclipse.jetty.io.ChannelEndPoint$2.run(ChannelEndPoint.java:124)
  at org.eclipse.jetty.util.thread.Invocable.invokePreferred(Invocable.java:128)
  at org.eclipse.jetty.util.thread.Invocable$InvocableExecutor.invoke(Invocable.java:222)
  at org.eclipse.jetty.util.thread.strategy.EatWhatYouKill.doProduce(EatWhatYouKill.java:294)
  at org.eclipse.jetty.util.thread.strategy.EatWhatYouKill.produce(EatWhatYouKill.java:126)
  at org.eclipse.jetty.util.thread.QueuedThreadPool.runJob(QueuedThreadPool.java:673)
  at org.eclipse.jetty.util.thread.QueuedThreadPool$2.run(QueuedThreadPool.java:591)
  at java.lang.Thread.run(Thread.java:745)
&lt;/pre&gt;
&lt;hr&gt;&lt;a href="http://eclipse.org/jetty"&gt;Powered by Jetty:// 9.4.6.v20170531&lt;/a&gt;&lt;hr/&gt;

&lt;/body&gt;
&lt;/html&gt;
</pre>

You could define a **GenericExceptionMapperProvider implements ExceptionMapper&lt;Throwable&gt;** such as:

<pre>
<code class="language-java">
package com.nafiux.ncp.base.exception;

import javax.ws.rs.core.Response;
import javax.ws.rs.ext.ExceptionMapper;
import javax.ws.rs.ext.Provider;

@Provider
public class GenericExceptionMapperProvider implements ExceptionMapper&lt;Throwable&gt; {

  class ErrorMessage {
    int status;
    String message;
    String developerMessage;

    public ErrorMessage(int status, String message) {
      this.status = status;
      String[] messages = message.split("\\|");
      this.message = messages[0];
      if(messages.length > 1) {
        this.developerMessage = messages[1];
      }
    }

    public int getStatus() { return this.status; }
    public String getMessage() { return this.message; }
    public String getDeveloperMessage() { return this.developerMessage; }
  }

  public Response toResponse(Throwable ex) {

    ErrorMessage errorMessage = new ErrorMessage(500, "An internal error has occurred|Perhaps here the REQUESTID or some reference that could help you to track the problem...");
    return Response.serverError().entity(errorMessage).build();

  }

}
</code>
</pre>

As you can see now, the error is masqueraded:

<pre>
<code class="language-bash">
ignacio.ocampo@MXTI1-4WQG8WQ ~ $ curl -i -X POST -H "Content-Type: application/json" http://localhost:8080/api/uaa/svc/public/v1/auth/login -d '{"username": "invalid@user.com", "password": "changeme"}' && echo ""
HTTP/1.1 500 Server Error
Date: Mon, 07 Aug 2017 17:00:33 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Server: Jetty(9.4.6.v20170531)

{"status":500,"message":"An internal error has occurred","developerMessage":"Perhaps here the REQUESTID or some reference that could help you to track the problem..."}
</code>
</pre>

> JAX-RS supports exception inheritance as well. When an exception is thrown, JAX-RS will first try to find an **ExceptionMapper** for that exception’s type. If it cannot find one, it will look for a mapper that can handle the exception’s superclass. It will continue this process until there are no more superclasses to match against ([read more](https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/part1/chapter7/exception_handling.html#exception-mapping)).

Here some examples about errors formats from some well-known companies:

  * Amazon EC2: http://docs.aws.amazon.com/AWSEC2/latest/APIReference/errors-overview.html
  * Twitter: https://dev.twitter.com/overview/api/response-codes
  * IBM QRadar on Cloud: https://www.ibm.com/support/knowledgecenter/en/SSKMKU/com.ibm.qradar.doc/c_rest_api_errors.html

Reference:

  * https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/part1/chapter7/exception_handling.html
  * https://stackoverflow.com/questions/6115896/java-checked-vs-unchecked-exception-explanation
  * http://www.codingpedia.org/ama/error-handling-in-rest-api-with-jersey/
  * https://apigee.com/about/blog/technology/restful-api-design-what-about-errors