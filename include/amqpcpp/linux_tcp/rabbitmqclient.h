/**
 *  RabbitMQClient.h
 *
 *  Convenience wrapper around TcpConnection + TcpChannel for direct RabbitMQ usage.
 */

#pragma once

#include <string>

namespace AMQP {

/**
 *  Higher-level helper that owns both a TCP connection and one channel.
 *
 *  This class keeps the low-level asynchronous API intact, but exposes
 *  common RabbitMQ operations through one object so client code only has to
 *  manage a single instance.
 */
class RabbitMQClient
{
private:
    /**
     *  Owned TCP connection
     */
    TcpConnection _connection;

    /**
     *  Default channel bound to the connection
     */
    TcpChannel _channel;

public:
    /**
     *  Construct a direct RabbitMQ client.
     *
     *  @param handler  Event-loop aware TCP handler implementation
     *  @param address  RabbitMQ connection address, e.g. amqp://user:pass@host/vhost
     */
    RabbitMQClient(TcpHandler *handler, const Address &address) :
        _connection(handler, address),
        _channel(&_connection) {}

    /**
     *  No copying
     */
    RabbitMQClient(const RabbitMQClient &other) = delete;

    /**
     *  No assignment
     */
    RabbitMQClient &operator=(const RabbitMQClient &other) = delete;

    /**
     *  Default move support
     */
    RabbitMQClient(RabbitMQClient &&other) = default;

    /**
     *  Default destructor
     */
    virtual ~RabbitMQClient() = default;

    /**
     *  Access the owned connection
     *  @return TcpConnection&
     */
    TcpConnection &connection()
    {
        return _connection;
    }

    /**
     *  Access the default channel
     *  @return TcpChannel&
     */
    TcpChannel &channel()
    {
        return _channel;
    }

    /**
     *  Declare an exchange
     */
    Deferred &declareExchange(const std::string &name, ExchangeType type = fanout, int flags = 0)
    {
        return _channel.declareExchange(name, type, flags);
    }

    /**
     *  Declare a queue
     */
    DeferredQueue &declareQueue(const std::string &name, int flags = 0)
    {
        return _channel.declareQueue(name, flags);
    }

    /**
     *  Bind a queue to an exchange
     */
    Deferred &bindQueue(const std::string &exchange, const std::string &queue, const std::string &routingKey = "")
    {
        return _channel.bindQueue(exchange, queue, routingKey);
    }

    /**
     *  Publish a message payload
     */
    bool publish(const std::string &exchange, const std::string &routingKey, const std::string &payload, int flags = 0)
    {
        return _channel.publish(exchange, routingKey, payload, flags);
    }

    /**
     *  Start consuming a queue.
     *
     *  @param queue         Queue name
     *  @param onMessage     Message callback
     *  @param autoAck       True to automatically ack each message
     *  @param flags         Consumer flags
     */
    DeferredConsumer &consume(const std::string &queue, const MessageCallback &onMessage, bool autoAck = true, int flags = 0)
    {
        return _channel.consume(queue, flags).onReceived([this, onMessage, autoAck](const Message &message, uint64_t deliveryTag, bool redelivered) {
            onMessage(message, deliveryTag, redelivered);
            if (autoAck) _channel.ack(deliveryTag);
        });
    }

    /**
     *  Close the connection
     */
    bool close(bool immediate = false)
    {
        return _connection.close(immediate);
    }
};

}
