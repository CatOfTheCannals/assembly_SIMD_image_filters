## assembly_image_filters
Series of SIMD assembly implementations, benchmarking versus non-parallel versions.

### Code
**Main:** `src/tp2.c`

**Image filters:** `src/filters/`

### Compile:

`make`

### Run main with different filters:
The files will be saved to `./outputs`.

`./build/tp2 Cuadrados ./img/colores32.bmp -i c -o outputs`

`./build/tp2 Manchas ./img/colores32.bmp -i c -o outputs`

`./build/tp2 Offset ./img/colores32.bmp -i c -o outputs`

`./build/tp2 Ruido ./img/colores32.bmp -i c -o outputs`

`./build/tp2 Sharpen ./img/colores32.bmp -i c -o outputs`

### Performance benchmarks
Find them in `src/exp/`.

Also in either of the two notebooks you will find a python *class ExpRunner* that lets you run binary code.
