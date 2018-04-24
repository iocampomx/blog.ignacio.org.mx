+++
title = "java.io - Understanding the limits of web synchronous programming based apps"
tags = ["java", "threads", "synchronous", "java.io", "sockets"]
date = "2018-04-23"
+++

## Introduction

I want to have a high performance API Gateway that scales well.

I heard about [**Zuul 2**](https://github.com/Netflix/zuul) (non-blocking gateway) on top of [**Netty**](http://netty.io/), *an asynchronous event-driven network application framework* based on Java NIO.

There are great articles about [**Zuul 1**](https://medium.com/netflix-techblog/announcing-zuul-edge-service-in-the-cloud-ab3af5be08ee) & [**Zuul 2**](https://medium.com/netflix-techblog/zuul-2-the-netflix-journey-to-asynchronous-non-blocking-systems-45947377fb5c) out there, I found this [**video**](https://www.youtube.com/watch?v=2oXqbLhMS_A) very helpful to understand Zuul's evolution and Netflix's journey on this.

I don't have solid knowledge about **java.nio API** yet, and, since **Zuul 2** is an evolution of **Zuul 1**, which was based on synchronous (blocking) programming, before learn **java.nio API** I need to understand the limitations of why the synchronous (blocking) applications does not scale well, this article is about that.

## Must-read resources

I found these resources very valuables as a foundation before get started:

 * [C10k problem](https://en.wikipedia.org/wiki/C10k_problem)
 * [JDK 8 - Lesson: Concurrency](https://docs.oracle.com/javase/tutorial/essential/concurrency/index.html)

Most of the examples were taken from [ITT 2015 - Heinz Kabutz - The Multi-threading, Non Blocking IO](https://www.youtube.com/watch?v=uKc0Gx_lPsg), I did some changes to understand better and explain more some concepts.

## Single-thread server

The example below is a simple echo server, it uses the java.io standard libraries and runs with one thread-only (main thread) to accept & handle connections.

<!--
**Note:** Unless otherwise specified, all the code shown on this document was compiled and executed with **Java 8** in a **Mac OS X 10.12.6**, Processor **2.8 GHz Intel Core i7**, Memory **16 GB 1600 MHz DDR3**.
-->

*SimpleEchoBlockingServer.java*
```java
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.ServerSocket;

public class SimpleEchoBlockingServer {
  public static void main(String... args) throws IOException {
    ServerSocket ss = new ServerSocket(8080);
    while(true) {
      // accept() is a blocking call, it will wait forever
      // until someone connects, it never returns null
      System.out.println("Waiting for a new to connect...");
      Socket s = ss.accept(); // blocked...
      System.out.println("A new client is connected " + s.toString());

      // handler(Socket) is a blocking call, it will run until the established connection is closed
      System.out.println("Starting handling client communication...");
      handler(s); // blocked...
      System.out.println("Connection has been closed...");
    }
  }

  private static void handler(Socket s) {
    try ( // try-with-resources statement
      InputStream in = s.getInputStream();
      OutputStream out = s.getOutputStream();
    ) {
      int data;
      while((data = in.read()) != -1) {
        out.write(data);
      }
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }
}
```

<p style="padding: 32px; background-color: #C0C0C0; font-style: italic;">
The <a href="https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html">try-with-resources statement</a> is a try statement that declares one or more resources. A resource is an object that must be closed after the program is finished with it. The try-with-resources statement ensures that each resource is closed at the end of the statement. Any object that implements <strong>java.lang.AutoCloseable</strong>, which includes all objects which implement <strong>java.io.Closeable</strong>, can be used as a resource.
</p>

[InputStream](https://docs.oracle.com/javase/7/docs/api/java/io/InputStream.html) and [OutputStream](https://docs.oracle.com/javase/7/docs/api/java/io/OutputStream.html) does implement [Closeable](https://docs.oracle.com/javase/7/docs/api/java/io/Closeable.html) & [AutoCloseable](https://docs.oracle.com/javase/7/docs/api/java/lang/AutoCloseable.html) interfaces.

**SimpleEchoBlockingServer execution**

![SimpleEchoBlockingServer-demo1](/posts/java%20nio/SimpleEchoBlockingServer-demo1.png)

**Client A connected first, Client B was waiting to be accepted**

![TelnetClientDemo1](/posts/java%20nio/TelnetClientDemo1.png)

Client A & B sent two messages, "hello" & "world" respectively, but only Client A received the echo response, Client B was still waiting.

As soon as Client A closed the connection, Client B was accepted and handled, receiving the echo message as well.

![TelnetClientDemo2](/posts/java%20nio/TelnetClientDemo2.png)

The server was only able to accept & handle 1 client at time.

How the server can accept multiple connections at same time? **Threads!** See next section.

## Multi-thread server

I modified the SimpleEchoBlockingServer.java to start a new thread to handle (blocking-function) clients communication:

*SimpleEchoBlockingServerThreaded.java*
```java
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.ServerSocket;

public class SimpleEchoBlockingServerThreaded {
  public static void main(String... args) {
    try {
      ServerSocket ss = new ServerSocket(8080);
      while(true) {
        // accept() is a blocking call, it will wait forever
        // until someone connects, it never returns null
        System.out.println("Waiting for a new client to connect...");
        Socket s = ss.accept(); // blocked...
        System.out.println("A new client is connected " + s.toString());
        
        // Creating a thread for each new connection
        Thread thread = new Thread(() -> handler(s));
        System.out.println("Starting new thread to handle client communication...");
        thread.start();
        System.out.println(thread.getName() + " > " + s.toString());
      }
    } catch (IOException e) {
      System.err.println(e);
    }
  }

  private static void handler(Socket s) {
    try ( // try-with-resources statement
      InputStream in = s.getInputStream();
      OutputStream out = s.getOutputStream();
    ) {
      int data;
      while((data = in.read()) != -1) {
        out.write(data);
      }
      System.out.println("Client " + s.toString() + " has closed the connection.");
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }
}
```

The enhanced server was able to handle multiple clients at same time:

![SimpleEchoBlockingServerThreaded-demo1](/posts/java%20nio/SimpleEchoBlockingServerThreaded-demo1.png)

I connected the Client A & B, and I closed B first and A later as shown in the server logs.

How efficient is the new server? How many clients/threads is able to handle at same time? Lets create a crazy client.

```java
import java.net.Socket;
import java.io.IOException;

public class CrazyClient {
  public static void main(String... args) throws InterruptedException {
    Socket[] sockets = new Socket[3000];
    for(int i=0; i<sockets.length; i++) {
      try {
        sockets[i] = new Socket("localhost", 8080);        
      } catch(IOException e) {
        System.err.println(e);
      }
    }
    Thread.sleep(1000000000);
  }
}
```

Here the tests:

![CrazyClientServerThreaded-demo1.png](/posts/java%20nio/CrazyClientServerThreaded-demo1.png)

I connected telnet client first, it was able to talk with the server, but after launched the CrazyClient, the server thrown a java.lang.OutOfMemoryError exception.

Were connected clients able to talk with the server after the exception? **Yes!**

![CrazyClientServerThreaded-demo2.png](/posts/java%20nio/CrazyClientServerThreaded-demo2.png)

It seems that the java.lang.OutOfMemoryError exception did interrupted the main thread of the server, which was running the main method with the while loop (accept & handle logic), however, other threads were still running.

What happened when CrazyClient was killed (I did manually CTRL+C)? The server closed all connections belonged to CrazyClient.

![CrazyClientServerThreaded-demo3.png](/posts/java%20nio/CrazyClientServerThreaded-demo3.png)

Was a new client able to connect to the server after the exception? Of course no, since the exception did exit the while loop of the server that was accepting new connections.

What happened when I closed the last and only telnet client that was still connected? The server app finished.

![CrazyClientServerThreaded-demo4.png](/posts/java%20nio/CrazyClientServerThreaded-demo4.png)

Which is the maximum number of threads, and therefore, number of clients the server can accept & handle? On Mac OS X, that depends on ``sysctl kern.num_taskthreads = 2048``

![CrazyClientServerThreaded-demo5.png](/posts/java%20nio/CrazyClientServerThreaded-demo5.png)

Why was I only able to launch 2025+1 (it starts with thread 0 after main) threads based on the server log? What happened with the (2048 - 2026) 22 threads missing?

I found that ``java SimpleEchoBlockingServerThreaded`` process was using 22 threads even without any client connected at the begining.

![CrazyClientServerThreaded-demo6.png](/posts/java%20nio/CrazyClientServerThreaded-demo6.png)

When I ran the CrazyClient, I saw the the server reached the limit of 2048 threads, which are 22 (base threads without clients) + 2026 (threads created for clients) = 2048 threads (maximum number of threads per process allowerd in Mac OS X)

![CrazyClientServerThreaded-demo7.png](/posts/java%20nio/CrazyClientServerThreaded-demo7.png)

Can I increase the limit of threads allowed per process in Mac? I don't think so, after spent almost 30 mins trying to find a way, every post I read shown the same note about ``kern.num_taskthreads = 2048`` that can't be increased on Mac OS X, I also checked ``man sysctl``:

     The changeable column indicates whether a process with appropriate privilege can change the value.
     String and integer values can be set using sysctl.

     Name                                        Type          Changeable
     ...
     kern.num_taskthreads                        integer       no
     ...

You may ask: Why too many threads? What you’re trying to accomplish? Well, just to understand how the limits works, I already know that the more number of open threads a process handle, the more memory and cpu it uses (waste of resources).

Which are the limits in other environments?

OS                   | Resources                         | Max threads | Changeable
---------------------|-----------------------------------|-------------|------------------------------
Mac 10.12.6 (Laptop) | 16 GB Ram - 2.8 GHz Intel Core i7 | 2014        | No
AWS EC2 t2.micro  *  | 1 GB                              | 7808        | I wasn't able to test it yet
AWS EC2 t2.small  *  | 2 GB                              | 15869       | I wasn't able to test it yet
AWS EC2 t2.medium *  | 4 GB                              | 31411       | I wasn't able to test it yet

\* Command used in Linux was ``sysctl kernel.threads-max``.

I ran a test in AWS EC2 t2.medium and despite the max number of threads seems to be 31411 I was only able to create 4089, I got this error:

```bash
Thread-4089 > Socket[addr=/127.0.0.1,port=35524,localport=8080]
Waiting for a new client to connect...
java.net.SocketException: Too many open files (Accept failed)
```

Why? Because each socket uses a file descriptor, the max number of open file descriptors is also constrained by the OS, the hard limit was 4096 (see image below).

Which is the max number file descriptors allowed by the OS? There is a command named ``ulimit`` that:

<p style="padding: 32px; background-color: #C0C0C0; font-style: italic;">
Provides control over the resources available to the shell and to processes started by it, on systems that allow such control.
</p>

Here the limits:

![FileDescriptorsLimits.png](/posts/java%20nio/FileDescriptorsLimits.png)

Enough! Anyway, this isn't efficient, lets move to the next spike.

How the server can accept multiple connections at same time without reach the limit and die (or be killed by the OS)? **Thread-Pools!** See next section.

## Thread-pool server

Instead of create an unlimited number of threads per connection, lets implement [**Thread Pools**](https://docs.oracle.com/javase/tutorial/essential/concurrency/pools.html), here a couple of paragraphs from the official documentation of Oracle that explains better their purpose:

<p style="padding: 32px; background-color: #C0C0C0; font-style: italic;">
One common type of thread pool is the fixed thread pool. This type of pool always has a specified number of threads running; if a thread is somehow terminated while it is still in use, it is automatically replaced with a new thread. Tasks are submitted to the pool via an internal queue, which holds extra tasks whenever there are more active tasks than threads.

<br /><br />

An important advantage of the fixed thread pool is that applications using it degrade gracefully. To understand this, consider a web server application where each HTTP request is handled by a separate thread. If the application simply creates a new thread for every new HTTP request, and the system receives more requests than it can handle immediately, the application will suddenly stop responding to all requests when the overhead of all those threads exceed the capacity of the system. With a limit on the number of the threads that can be created, the application will not be servicing HTTP requests as quickly as they come in, but it will be servicing them as quickly as the system can sustain.
</p>

```java
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.ServerSocket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SimpleEchoBlockingServerThreadPool {
  public static void main(String... args) {
    try {
      ServerSocket ss = new ServerSocket(8080);
      ExecutorService pool = Executors.newFixedThreadPool(100);
      while(true) {
        // accept() is a blocking call, it will wait forever
        // until someone connects, it never returns null
        Socket s = ss.accept(); // blocked...
        // Submits a runable task to the pool per each connection accepted to handle the communication...
        pool.submit(() -> handler(s));
      }
    } catch (IOException e) {
      System.err.println(e);
    }
  }

  private static void handler(Socket s) {
    System.out.println(Thread.currentThread().getName() + " > " + s.toString() + " handled started...");
    try ( // try-with-resources statement
      InputStream in = s.getInputStream();
      OutputStream out = s.getOutputStream();
    ) {
      int data;
      while((data = in.read()) != -1) {
        out.write(data);
      }
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
    System.out.println(Thread.currentThread().getName() + " > " + s.toString() + " has closed the connection!");
  }
}
```

Here what happened after ran the Thread Pool server & CrazyClient:

![ThreadPoolExample-1.png](/posts/java%20nio/ThreadPoolExample-1.png)

Even though CrazyClient tried to create 3000 connections, the server only created 100 threads to handle connections (it didn't any memory error). Later, I closed CrazyClient:

![ThreadPoolExample-2.png](/posts/java%20nio/ThreadPoolExample-2.png)

## Conclusion

Using Thread Pools was safe for the server and the clients already connected, but wasn't optimal for new clients trying to connect. In fact, CrazyClient didn't anything after the connection were stablished, it just was waiting for long time wasting resources (threads) of the server (this sounds like [DoS attack](https://en.wikipedia.org/wiki/Denial-of-service_attack)), that could be used by other very valuable clients.

Of course these examples were very basic, there are few techniques to helps the servers con prevent attacks.

In order to support thousands of clients, one solution could be create a load balancer with several nodes serving connections, this is/was the most common strategy used by the industry based on thread-blocking solutions.

What is next? Create asynchronous event-driven network applications, in Java world, **java.nio API** and Netty seems to be a good option. Coming soon!

## Related articles

* [Tuning Tomcat For A High Throughput, Fail Fast System](https://medium.com/netflix-techblog/tuning-tomcat-for-a-high-throughput-fail-fast-system-e4d7b2fc163f)
