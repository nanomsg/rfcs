# User Datagram Protocol Mapping for Scalability Protocols

![draft](https://img.shields.io/badge/status-draft-yellow.svg?style=for-the-badge)

## User Datagram Protocol (UDP) Mapping for Scalability Protocols

* Status: draft
* Authors: [Garrett D'Amore](mailto:garrett@damore.org)
* Version 0.11

## Abstract

This document defines the User Datagram Protocol (UDP) mapping
for scalability protocols.
This enables SP protocols to run over a basic UDP session.

This mapping is designed to support basic ordering (which might be used
to detect message loss as well), as well as being simple enough for
implementation in extremely limited environments such as 16-bit microcontrollers.

This specification is for UNICAST UDP only.
Operation with broadcast and multicast style will be specified in a
future specification.

## License

Copyright 2024 [Staysail Systems, Inc.](mailto:info@staysail.tech)

This specification is licensed under the Apache License, Version 2.0
(the "License");  you may not use this file except in compliance with the
License.
You may obtain a copy of the license
[online](http://www.apache.org/licenses/LICENSE-2.0).

## Language

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [RFC 2119](https://tools.ietf.org/html/rfc2119).

## Underlying protocol

UDP is a message-oriented, connectionless, unordered, best-effort protocol that sits on
top of Internet Protocol - either version IP version 4 or 6.
It is described in [RFC 768](https://tools.ietf.org/html/rfc768), and is largely
unchanged even in IPv6.


### Message framing

This mapping relies on UDP message delimiting for SP messages.
That is each UDP message matches at most one SP message.

As a consequence, this transport is unable to process messages that exceed the
maximum UDP payload size, which is typically 65536 octets minus space used for
headers. (For IPv6 the IP/UDP headers are 48 bytes).

Further, the use of UDP packet fragmentation often leads at best to
poor performance, and frequently to increased packet losses, particularly
when the underlying medium is not itself reliable.
Many sites also prohibit UDP fragmentation administratively (and this is
the standard with IPv6.)

In general IPv6 establishes a requirement that networks must be able to
pass messages of at least 1280 bytes without fragmenting them.  Subtracting
48 bytes for the IP/UDP headers gives a maximum UDP paylod size without
fragmenting of 1232 bytes.  (IPv4 networks can have much smaller MTUs
in principal, but in practice none do.)

This specification requires 16 bytes of the UDP payload for its own use,
leaving 1216 for SP use in the worst case.  (IP/UDP/transport headers add
to 64 bytes for IPv6, 44 bytes for IPv4).  Individual protocols may require
additional space for backtraces, etc.

Consequently, applications should not expect to be able to use this transport
for messages larger than the maximum transmission unit (MTU) of the path
between sender and receiver.

In order to avoid special cases for IPv4 and IPv6 and allow room for possible
future expansion, this specification limits the total payload size to 65000
bytes.

### UDP Port Assignment

No fixed UDP port assignment is made.
Applications using this mapping will need to pre-arrange to communicate using
UDP ports of their choosing.

A connected pair is determined by the combination of IP address and UDP port
(i.e. the full L4 address) for the parties in question.  As the accepter must
use a fixed port, the initiator SHOULD use a unique ephemeral port
for each logical connection.

## Packet Fields

Every UDP message consists of a twenty octet header, followed by the
message payload.  (While not every messages every field in the header,
the use of a fixed size header simplifies implementation.)

In the fields below, all fields are constructed in little endian order.
That is, the least significant byte comes first.  Note that this is the opposite
of all other (at this time) SP protocols, and is made as a concession to
the fact nearly every modern CPU is little endian.

The message header is structured as follows:

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |     opcode    |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       peer identification                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            length             |            reserved           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        payload ...
+-+-+-+-+-+-+-+-+-+-+-+-+-
```

the first octet (0x01) is used to provide version field, so that
this protocol can evolve in the future.  it must be set to 0x01.

### opcode

the second octet of an sp-udp message is an operation code, indicating
how the purpose of the message.

the following opcodes are defined:

0x00 - `DATA`: the packet carries sp payload data.
0x01 - `CREQ`: the packet initiates a logical connection.
0x02 - `CACK`: the packet confirms creation of a logical connection.
0x03 - `DISC`: the packet terminates the logical connection.
0x04 - `MESH`: the packet is used to form a mesh.

the following opcodes are reserved for use with multicast:

0x10-0x1f: reserved for multicast (to be specified).

### type

The type is 16-bit little-endian value that indicates
the protocol the SP protocol implemented by the sender.

The mapping SHOULD NOT interpret this field, but upper layer specific
protocol should validate that the peer is compatible.

Every message in sent by this mapping MUST have a valid SP type.

An implementation MUST NOT use a different value for the SP type within
a given logical connection.

### Reserved Field

Any reserved fields MUST be zero.

### Sender Identification

The sender id is intended to facilitate detection of a change in a remote
peer (for example if a peer restarts).  A given sender shall always use the
same value for a given logical connection.

Implementations MUST use unique values for each logical connection.

The sender id MUST NOT be zero.

A receiver MAY drop a message that should have been associated with a
logical connection but has a different sender id.  It MAY also send a
`DISC` message referencing the incorrect sender id.

### Peer Identification

The peer identification is used to facilitate look up of connections
for peers.  The sender should includes the peer's identification (which
was obtained during connection establishment, and is copied from the peer's
sender identification -- see above) for any messages that relate
to an established connection.

The recipient may use this to validate an established connection, and
SHOULD drop the message if it does not recognize the identification,
or if the identification appears to come from a different sender
than the address associated with the logical connection.

A receiver MAY also respond with a `DISC` message if the peer identification
is not one it recognizes.

## Sender Sequence Number

The sender sequence number is initialized to a value (which MAY be random
or any other value but SHOULD reset to the same value for each incarnation
of an application, if not random), which the recipient MAY use to detect
lost, duplicated, or reordered messages.

IMPORTANT: This is a little-endian field.

Each new message sent by a sender on the same logical connection MUST increment
the sender sequence number, wrapping to zero when incrementing past 0xFFFFFFFF.

Recipients SHOULD examine the sequence number.

When the received sequence number is equal to the most recently received
sequence number (on the same logical connection) plus one, then no message
loss or reordering has occurred.

When it is equal to the most recently received sequence number, then a
message is presumably duplicated.

When the received sequence number is ahead of the most recently
received sequence by more than 1, and less than 2^30, then the receiver
SHOULD assume that some message loss has occurred, but SHOULD accept the
message as is and take any appropriate actions (such as incrementing a
statistic) for lost messages.

When the received sequence number is behind the most recently received
message message sequence by less than 2^30, then the message is assumed to be
received out of order, and the receiver MUST drop the message.  It SHOULD
also increment a statistic.

If the received sequence number has not changed since the last message,
then the message is a duplicate, and MUST be dropped.  The receiver SHOULD
also incrementa a statistic.

If the difference between most recently received message and the current
sequence number is larger than 2^30, the receiver SHOULD assume the
sequence number has been reset, and accept the message, along with
incrementing a statistic.

### Payload

The payload specifics are detailed for each message type.
However, the payload MUST NOT be larger than 65000 octets.

## Connection Management

UDP is a connectionless protocol, but SP is designed with connections
as a fundamental part of its architecture.  This is used to track
session state, and provide for application awareness of peer entities
in the network.

To support this, this mapping provides for a "logical" connection between
peers using this mapping.

Connections are initiated by an "initiator", and are accepted by an "accepter".

A connection is normally initiated by an initiator sending a `CREQ` message.

The connection is "accepted" by an "accepter", who responds by sending a `CACK`
message in reply.

Keepalives and self-healing is implemented by the initiator periodically
sending `CREQ` messages at the negotiated refresh interval (_refresh_)
(see the `CREQ` message format below)
and by the accepter sending `CACK` messages in response.

Either party may send `CREQ` or `CACK` messages more frequently than the
negotiated refresh interval.

If a connection was lost (such as if the accepter restarted), then
the arrival of new `CREQ` messages will automatically recreate the
connection.

If either party does not receive any message for some time longer than the
negotiated refresh interval then it SHOULD assume the other party is gone and
terminate the connection.

At any time either side may terminate the connection with a `DISC` message.
Upon either sending or receiving such a message, the mapping should stop
all further send or receive activity on the connection.

A new connection may be requested with further `CREQ` messages.

Unicast `DATA` messages received that do not correspond to an open connection
SHOULD be responded to with a `DISC`.

## Data Message (DATA)

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |  DATA (0x00)  |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       peer identification                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|          payload size         |          reserved             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        user payload ...
+-+-+-+-+-+-+-+-+-+-+-+-+-
```

Data messages are unicast messages sent to a peer.

The _payload_ is SP protocol payload, specific to each protocol.
For example, _REQ_ protocol will contain a set of backtrace headers followed
by the application payload.

Unicast `DATA` messages received that do not correspond to an open connection
SHOULD be responded to with a `DISC`.

The payload size reflects the payload size, and is present to permit
detection of truncation.

## Connection Request (CREQ)

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |  CREQ (0x01)  |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       peer identification                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     maximum payload size      |    reserved   |    refresh    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

An initiator sends a `CREQ` when initiating a unicast logical connection
to a peer.  This is also sent periodically to keep the connection "alive",
thereby preventing resources from being reaped on the peer.

The _sender identification_ SHOULD be a random number determined by the
initiator to refer to this connection.  It MUST NOT change for a given
connection, and it MUST NOT be zero.

When first starting the sender does not yet know the _peer identification_
and that field MUST be zero. Once a connection is established the sender
MUST supply the correct value for the _peer identification_ that was
determined previously.

The value _refresh_ is an interval in seconds (1-255). The initiator
guarantees that it will send a `CREQ` message at least once per such interval.
a `CREQ` will be sent at intervals between 1 and 255 seconds.)

A _refresh_ value of zero is reserved, and MUST NOT be used.

Implementations SHOULD use this value to determine how long to keep a
connection alive when no traffic otherwise is seen.  They SHOULD assume
data loss can occur, and thus a small multiple between 2 and 8 should be used
to allow for message loss before assuming the peer is no longer online.

The _maximum payload size_ is an indication to the peer about the maximuim
SP message size (in bytes) (i.e. the maximum payload for this transport)
that the receiver is willing or able to receive.
If the value zero is specified, then there is no limit apart from that imposed
by the networking layer (which will not be larger than 64KB in any case).
Note carefully that the message header (`DATA`) is not included in the size.
Given that UDP cannot send a message larger than 64KB minus the IP/UDP
headers, the maximum practical value of this field will be less than 65535.

Note that when an initiator sends subsequent `CREQ` messages as part of
the keep alive requirement, all of the fields of the message MUST be the same
as the initial message, _except_ for the sequence number, of course.

The accepter may require a shorter refresh interval.
In any event, the accepter MUST send the shorter of the _refresh_ value
sent by the initiator, or the value it is willing to accept, in its `CACK`
response.

If the initiator finds the new minimum unacceptable, it SHOULD
disconnect with a `DISC` message.

An accepter MUST respond to a `CREQ` with a `CACK` message on success.

It MAY instead send a `DISC` message if it wishes to refuse the connection
request.  (It MAY also simply decline to respond entirely.)

## Connection Acknowledgement (CACK)

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |  CACK (0x02)  |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       peer identification                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     maximum payload size      |    reserved   |    refresh    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

A connection acknowledgement is sent by an accepter in response to a connection
request (`CREQ`).

The semantics of the fields in this message are the same as for `CREQ`,
except of course that the _refresh_ may provide a shorter (but non-zero)
value. Additionally the _maximum payload size_
reflects the maximum message size the accepter is willing to accept from
the initiator, and this may be different than the other way around.

There is no application payload associated with `CACK`.

## Disconnect Message (DISC)

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |  DISC (0x03)  |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                       peer identification                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|            reason             |          reserved             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

Disconnect messages are sent to terminate an existing connection, or to reject
an attempt to form a new connection.

This message SHOULD be sent by a party when it is shutting down, in order to
assist the peer in cleaning up state kept for the connection.
However, implementations MUST NOT rely soley on the receipt of `DISC` messages
to perform that clean up, but instead utilize keep alive timeouts.

If the `DISC` message is being sent to reject a new connection request, the
_sender identification_ and _sender sequence_ SHOULD be zero.
The _type_ field MAY also be zero in this circumstance.

The _peer identification_ MUST be the same value received from the peer in
either a `CREQ` or `CACK` message.

A `DISC` message with an incorrect _peer identification_ field MUST be ignored.

The _reason_ field is an indication of the reason for terminating the connection.
The following reserved values for _reason_ are supplied:

0: Connection closed normally. (Application shut down, etc.)
1: Incorrect _type_.  (The receiver cannot process messages from the sender's _type_.)
2: No connection.  (No connection for the given sender and peer exists.)
3: Refused.  (Such as due to incorrect permissions or policy or rejecting incoming connections.)
4: Message too large.  (Sender did not comply to _max message size_.)
5: Negotiation of either _refresh interval_ failed.
6: Connection timed out.  (No refreshed `CACK` or `CREQ` received.)
7: Protocol error.  (E.g. bad _opcode_ or some other protocol error.)
8: Resources exhausted.  (E.g. unable to allocate logical connection.)

Other values of _reason_ may be added.
Values smaller than 32767 are reserved for future specifications.
Values larger than or equal to 32768 are available for local use.

## Mesh Connection (MESH)

```
0                   1                   2                   3
0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      0x01     |  MESH (0x04)  |             type              |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                      sender identification                    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                            reserved                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         sender sequence                       |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     maximum payload size      |    reserved   |    refresh    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

Mesh Connection messages are sent by a sender to "unknown" peers,
making use of either broadcast or multicast (but note that unicast
is allowed too) to announce their readiness for incoming connection
requests.

This can be used to create a sort of mesh, where multiple parties
each use this to announce their willingness to receive connections.

Upon receipt of such a message, the receiving party MAY elect to
start a connection process ot the sender.  It SHOULD only do so
if it does not already have an existing connection with the peer
identified by the sender identification.
A recipient MUST NOT send a DISC message in response to these
messsages.

The _maximum payload_size_ and _refresh_ values are advisory only,
and SHOULD reflect the values that the orginator will send in
a `CACK` message (in response to a `CREQ`.)
