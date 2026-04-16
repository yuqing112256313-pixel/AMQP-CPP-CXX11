AMQP-CPP
========

[![Build Status](https://travis-ci.org/CopernicaMarketingSoftware/AMQP-CPP.svg?branch=master)](https://travis-ci.org/CopernicaMarketingSoftware/AMQP-CPP)
[![Build status](https://ci.appveyor.com/api/projects/status/heh4n7gjwgqcugfn/branch/master?svg=true)](https://ci.appveyor.com/project/copernica/amqp-cpp/branch/master)

AMQP-CPP 是一个用于与 RabbitMQ 消息代理通信的 C++ 库。
它可以解析从 RabbitMQ 收到的数据，也可以生成发送给 RabbitMQ 的 AMQP 帧。

概览
====

**如果你正在从 AMQP-CPP 3 升级到 AMQP-CPP 4，请先阅读 [升级说明](#升级说明)。**

> 说明：原始 README 先介绍“底层、手动管理网络”的用法，再介绍更常用的 TCP 接口。
> 绝大多数场景推荐直接使用后文的 TCP 接口。

AMQP-CPP 采用分层架构：

- 你可以完全自行管理网络层（自己建连、收发、事件循环）。
- 也可以使用库内置的 TCP/TLS 模块，让库负责网络与可选的 TLS 处理。

该架构使库具备良好的可移植性与灵活性，可集成到各种事件循环中。AMQP-CPP 为**全异步**实现，不进行阻塞系统调用，适用于高性能场景。

> 本库使用 C++11，请确保编译器支持 C++11。

目录
====

- [概览](#概览)
- [关于项目](#关于项目)
- [安装](#安装)
- [如何使用 AMQP-CPP](#如何使用-amqp-cpp)
- [解析入站数据](#解析入站数据)
- [TCP 连接](#tcp-连接)
- [安全连接 (TLS)](#安全连接-tls)
- [与事件循环集成](#与事件循环集成)
- [心跳](#心跳)
- [Channel 与回调](#channel-与回调)
- [消息发布](#消息发布)
- [发布确认 (Publisher Confirms)](#发布确认-publisher-confirms)
- [消息消费](#消息消费)
- [升级说明](#升级说明)

关于项目
========

本库由 Copernica 维护，并在其 MailerQ、Yothalot 等产品中使用。

- Copernica: https://www.copernica.com
- MailerQ: https://www.mailerq.com
- Yothalot: https://www.yothalot.com

安装
====

先克隆仓库：

```bash
git clone https://github.com/CopernicaMarketingSoftware/AMQP-CPP.git
cd AMQP-CPP
```

AMQP-CPP 支持两种构建方式：

- **CMake**：跨平台推荐方式
- **Makefile**：仅 Linux

构建后常用头文件：

| 文件 | 何时包含 |
|---|---|
| `amqpcpp.h` | 始终需要 |
| `amqpcpp/linux_tcp.h` | 使用 Linux TCP 模块时 |

> 在 Windows 上，包含公开头文件时应定义 `NOMINMAX`。

## 使用 CMake

```bash
mkdir build
cd build
cmake .. [-DAMQP-CPP_BUILD_SHARED=ON] [-DAMQP-CPP_LINUX_TCP=ON]
cmake --build . --target install
```

常用选项：

| 选项 | 默认值 | 说明 |
|---|---|---|
| `AMQP-CPP_BUILD_SHARED` | `OFF` | `OFF` 构建静态库，`ON` 构建共享库 |
| `AMQP-CPP_LINUX_TCP` | `OFF` | `ON` 构建 Linux TCP 模块（仅 Linux 支持） |

### Windows 发布包（`.dll + .lib + headers`）

```powershell
cmake -S . -B build -DAMQP-CPP_BUILD_SHARED=ON -DAMQP-CPP_LINUX_TCP=OFF
cmake --build build --config Release
cpack --config build/CPackConfig.cmake -C Release
```

生成的 ZIP 位于 `build/` 目录。

## 使用 make

```bash
make
make install
```

如果只安装核心库（不包含 TCP 模块）：

```bash
make pure
make install
```

打包共享库与头文件：

```bash
make package-shared
```

构建仅核心包（不含 `linux_tcp` 头）：

```bash
make package-shared WITH_LINUX_TCP=0
```

## 编译你的程序

使用 gcc/clang 链接 AMQP-CPP：

- `-lamqpcpp`
- 使用 TCP 模块时还需：`-lpthread -ldl`

示例：

```bash
g++ -g -Wall -lamqpcpp -lpthread -ldl my-amqp-cpp.cpp -o my-amqp-cpp
```

如何使用 AMQP-CPP
=================

AMQP-CPP 本身不做 IO。你需要提供一个实现 IO 行为的处理器对象。

核心做法：

1. 继承 `AMQP::ConnectionHandler`
2. 实现至少以下回调：
   - `onData()`：当库有数据要发给 RabbitMQ
   - `onReady()`：AMQP 握手成功，可开始业务操作
   - `onError()`：连接发生致命错误
   - `onClosed()`：连接正常关闭

示例：

```c++
#include <amqpcpp.h>

class MyConnectionHandler : public AMQP::ConnectionHandler
{
public:
    void onData(AMQP::Connection *connection, const char *data, size_t size) override
    {
        // 把 data 写到你的 socket
    }

    void onReady(AMQP::Connection *connection) override
    {
        // 连接已就绪，可创建 Channel 并开始收发消息
    }

    void onError(AMQP::Connection *connection, const char *message) override
    {
        // 记录错误并清理资源
    }

    void onClosed(AMQP::Connection *connection) override
    {
        // 处理关闭逻辑
    }
};
```

创建连接与通道：

```c++
MyConnectionHandler handler;
AMQP::Connection connection(&handler, AMQP::Login("guest", "guest"), "/");
AMQP::Channel channel(&connection);

channel.declareExchange("my-exchange", AMQP::fanout);
channel.declareQueue("my-queue");
channel.bindQueue("my-exchange", "my-queue", "my-routing-key");
```

> 注意：连接创建后会先进行 AMQP 握手。握手期间发起的操作会被缓存，待连接 ready 后执行。

解析入站数据
============

你需要在自己的事件循环中：

1. 检查 socket 可读
2. 读取数据（例如 `recv()`）
3. 调用 `Connection::parse(buffer, size)`

`parse()` 返回已处理字节数。
若只处理了部分数据，你需要保留剩余字节并在后续与新数据一起再次传入。

可利用：

- `Connection::expected()`：下一次更合适的输入大小
- `Connection::maxFrame()`：AMQP 最大帧尺寸（便于规划复用缓冲区）

TCP 连接
========

如果你不想自行管理网络，推荐使用 TCP 模块：

- `AMQP::TcpConnection`
- `AMQP::TcpChannel`
- 继承 `AMQP::TcpHandler`

`TcpHandler` 中通常只需重点实现 `monitor()` 来接入事件循环；其余回调大多可按需覆盖。

常见回调：

- `onAttached()`：连接对象绑定到 handler
- `onConnected()`：TCP 层连通
- `onSecured()`：TLS 建立完成（`amqps://`）
- `onReady()`：AMQP 层就绪
- `onError()/onLost()/onDetached()`：错误、断连、资源解绑

安全连接 (TLS)
===============

使用 `amqps://` 地址即可启用 TLS。你可以在 `onSecured()` 中检查证书、校验加密强度，然后决定是否继续。

与事件循环集成
==============

项目提供了针对常见事件循环的支持（如 libev/libuv/libevent 等场景）。
你可以：

- 直接使用已有适配
- 或在自定义事件循环中实现 handler 并手动驱动收发

心跳
====

AMQP 心跳可用于检测连接存活。心跳间隔由客户端与服务端协商。
若在心跳周期内未收到数据，应及时检查连接状态并执行重连策略。

Channel 与回调
==============

大多数 channel 操作都是异步的，返回 `Deferred` 对象，支持链式回调：

- `onSuccess(...)`
- `onError(...)`

常见失败包括：声明冲突、权限不足、参数非法、连接中断等。

消息发布
========

使用 `Channel::publish()` 可将消息发送到 exchange。
可选参数支持：

- routing key
- flags（如 `mandatory`）
- `Envelope`（携带 content-type、优先级、过期时间等元信息）

示例：

```c++
channel.publish("my-exchange", "my-key", "hello world");
```

如需更强一致性，可使用事务：

```c++
channel.startTransaction();
channel.publish("my-exchange", "my-key", "msg1");
channel.publish("my-exchange", "my-key", "msg2");

channel.commitTransaction()
    .onSuccess([]() {
        // 事务提交成功
    })
    .onError([](const char *message) {
        // 事务失败（消息未生效）
    });
```

发布确认 (Publisher Confirms)
==============================

开启 confirm 模式后，RabbitMQ 会对每次发布返回 ack/nack。

```c++
channel.confirmSelect()
    .onSuccess([&]() {
        channel.publish("my-exchange", "my-key", "first");
        channel.publish("my-exchange", "my-key", "second");
    })
    .onAck([&](uint64_t deliveryTag, bool multiple) {
        // 成功确认
    })
    .onNack([&](uint64_t deliveryTag, bool multiple, bool requeue) {
        // 失败确认
    });
```

辅助类：

- `AMQP::Reliable`：简化每条消息的确认处理
- `AMQP::Throttle`：限制并发未确认消息数，防止过载

消息消费
========

调用 `Channel::consume()` 开始消费，返回 `DeferredConsumer`，可注册：

- `onSuccess(...)`：消费启动成功
- `onReceived(...)`：收到消息
- `onCancelled(...)`：消费者被 broker 取消
- `onError(...)`：消费失败

示例：

```c++
channel.consume("my-queue")
    .onReceived([&](const AMQP::Message &message, uint64_t deliveryTag, bool redelivered) {
        // 处理消息
        channel.ack(deliveryTag); // 手动确认
    })
    .onSuccess([](const std::string &tag) {
        // 已开始消费
    })
    .onError([](const char *message) {
        // 消费失败
    });
```

`deliveryTag` 用于 ack/nack。若不开启 `noack`，处理完消息后应显式 `ack()`。

还可通过 `Channel::setQos()` 控制未确认消息上限（限流）。

升级说明
========

AMQP-CPP 4 与旧版本并非完全兼容，重点变化：

- `ConnectionHandler::onConnected` 重命名为 `onReady`
- `TcpHandler::onConnected` 触发时机提前（TCP 建立即触发）
- 新增 `TcpHandler::onReady`（AMQP 层就绪时触发）
- `TcpHandler::onError` 不再保证是最后回调
- `TcpHandler::onClosed` 表示 AMQP 协议层优雅关闭，而非 TCP 断开
- `TcpHandler::onLost` 用于 TCP 丢失/关闭
- `TcpHandler::onDetached` 更适合做清理

补充说明
========

当前 AMQP-CPP 已实现绝大多数常见功能。
如需深入了解所有 API、全部回调语义和完整示例，请结合以下文件阅读：

- `include/amqpcpp/connectionhandler.h`
- `include/amqpcpp/tcphandler.h`
- `include/amqpcpp/channel.h`
- `include/amqpcpp/message.h`
- `include/amqpcpp/envelope.h`
