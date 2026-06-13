
150 Entities moved using `Humanoid:MoveTo` every 0.1 seconds to a random location (Half ticking disabled). Chrono tickrate set to 10 TPS without full rotation.  Packet Size was measured using `Stats` service using `Stats.DataSendKbps + Stats.PhysicsSendKbps` with sampling done every 0.1 second and averaged over 60 seconds. 

| Mode | Server Send (Kbps) | Server Recv (Kbps) |
|---|---|---|
| **Server tests** | | |
| Native | 56.81 | - |
| Roblox | 34.57 | - |
| Native with lock | 28.98 | - |
| Custom | 22.10 | - |
| **Client tests** | | |
| Native | - | 50.49 |
| Roblox | - | 28.74 |
| Native with lock | - | 22.13 |
| Custom | - | 21.92 |

For the raw footage see: https://youtu.be/xo8EJ9YHSi4

See tests/benchEntities.luau for more details on the tests.
