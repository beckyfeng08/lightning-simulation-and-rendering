| Limit                          | default      |   rebecca  |    rose    | tom | bottleneck (min of all three)
|--------------------------------|--------------|------------|------------|--------|
| Storage binding size           | 128 MiB      | 4096 MiB   |   2048 MiB | 2048 MiB  |
| Max buffer size                | 256 MiB      | 4096 MiB   |   2048 MiB | 2048 MiB |
| Max storage buffers per stage  | 8            | 10         |    16      | 16 |
| Workgroup storage              | 16 KiB       | 32 KiB     |    32 KiB  |  32 KiB  |
| Max invocations per workgroup  | 256          | 1024       |   1024     |  1024  |
| Max workgroup size (x y z)     | 256 256 64   | 256 256 64 | 256 256 64 |   256 256 64 |


With current constraints, we can support max 134,217,728 cells (that is, 512 x 512 x 512 sized grid, or 30000 * 4473 sized grid)
- lightning bolt is 3000 meters long, then we are distance 447 meters away??
- we can also just cut the length of the lightning bolt to 1km, and so we get 1342.1 meters in width given dx of 0.1.

Given our hardware limits, we can only invoke 32 by 32 workgroups (1024 max invocations per workgroup)

For ten iterations (10 samples of recording)
- it takes 2 seconds to simulate something with 13,000,000 cells (1km * 130 meters)
- takes 21.8 seconds to simulate the full 130,000,000 cells (1km * 1.3km)

If we are simulating multiple lightning bolts then lerping their sounds, let's say across a 100 by 100 meter field, and each bolt every 10 meters (so we have 100 bolts to simulate), we want maybe a 10 second recording from the furthest bolt, that is 50000 iterations, or 5000 * 2 = 10,000 seconds = 166 minutes to simulate a single bolt...

if we do a 300 by 300 meter situation, then it takes 1 minute to simulate a 10 second recording. * 100 = 100 minutes to simulate whole grid

