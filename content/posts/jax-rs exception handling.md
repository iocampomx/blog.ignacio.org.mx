+++
title = "JAX-RS Exception Handling"
tags = ["microservices", "java", "jax-rs", "exceptions"]
date = "2017-08-06"
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
public class WebApplicationExceptionMapperProvider implements ExceptionMapper<WebApplicationException> {

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

(Apache CXF has an [WebApplicationExceptionMapper](https://github.com/apache/cxf/blob/master/rt/frontend/jaxrs/src/main/java/org/apache/cxf/jaxrs/impl/WebApplicationExceptionMapper.java) already defined and used by default, but it doesn't include the exception message in the response to the user/developer).

In the previous example, **WebApplicationExceptionMapperProvider** expect a `pipe (|)` as a separator in the exception message to split it in two kind of messages, the first part is a high level error message final user oriented, the second part is a more detailed error message developer oriented (upon each specific exception raised, if no pipe is provided, **developerMessage** isn't included in the response).

<pre>
<code class="language-java">

throw new ForbiddenException("Invalid username or password|Validate that you're sending the 'username' and 'password' in the payload");

</code>
</pre>

If you need to define your custom exceptions that doesn't extend from **WebApplicationException**, you should create also your own [ExceptionMapper](https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/part1/chapter7/exception_handling.html#exception-mapping) for that exception/s, so that you can provide the same level of detail in the response to the user.

Without **WebApplicationExceptionMapperProvider**:

<pre>
<code class="language-bash">
ignacio.ocampo@MXTI1-4WQG8WQ ~ $ curl -i -X POST -H "Content-Type: application/json" http://localhost:8080/api/uaa/svc/public/v1/auth/login -d '{"username": "invalid@user.com", "password": "changeme"}' && echo ""
HTTP/1.1 403 Forbidden
Date: Sun, 06 Aug 2017 21:03:11 GMT
Content-Length: 0
Server: Jetty(9.4.6.v20170531)

</code>
</pre>

With **WebApplicationExceptionMapperProvider**:

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

You should have in mind that there could be some hidden **RuntimeExceptions** (unchecked) that you won't see until they appears, specially when you're using third part libraries.

Here some examples about errors formats from some well-known companies:

  * Amazon EC2: http://docs.aws.amazon.com/AWSEC2/latest/APIReference/errors-overview.html
  * Twitter: https://dev.twitter.com/overview/api/response-codes
  * IBM QRadar on Cloud: https://www.ibm.com/support/knowledgecenter/en/SSKMKU/com.ibm.qradar.doc/c_rest_api_errors.html

A final note from [Oracle](http://docs.oracle.com/javase/tutorial/essential/exceptions/runtime.html):

> If a client can reasonably be expected to recover from an exception, make it a **checked exception**. If a client cannot do anything to recover from the exception, make it an **unchecked exception**.

Reference:

  * https://dennis-xlc.gitbooks.io/restful-java-with-jax-rs-2-0-2rd-edition/en/part1/chapter7/exception_handling.html
  * https://stackoverflow.com/questions/6115896/java-checked-vs-unchecked-exception-explanation
  * http://www.codingpedia.org/ama/error-handling-in-rest-api-with-jersey/
  * https://apigee.com/about/blog/technology/restful-api-design-what-about-errors