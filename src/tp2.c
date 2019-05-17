
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>
#include <math.h>

#include "tp2.h"
#include "helper/tiempo.h"
#include "helper/libbmp.h"
#include "helper/utils.h"
#include "helper/imagenes.h"

// ~~~ seteo de los filtros ~~~

extern filtro_t Cuadrados;
extern filtro_t Manchas;
extern filtro_t Offset;
extern filtro_t Ruido;
extern filtro_t Sharpen;

filtro_t filtros[5];

// ~~~ fin de seteo de filtros ~~~

int main( int argc, char** argv ) {

    filtros[0] = Cuadrados; 
    filtros[1] = Manchas;
    filtros[2] = Offset;
    filtros[3] = Ruido;
    filtros[4] = Sharpen;

    configuracion_t config;
    config.dst.width = 0;
    config.bits_src = 32;
    config.bits_dst = 32;

    procesar_opciones(argc, argv, &config);
    
    // Imprimo info
    /*
    if (!config.nombre) {
        printf ( "Procesando...\n");
        printf ( "  Filtro             : %s\n", config.nombre_filtro);
        printf ( "  Implementación     : %s\n", C_ASM( (&config) ) );
        printf ( "  Archivo de entrada : %s\n", config.archivo_entrada);
    }*/

    snprintf(config.archivo_salida, sizeof  (config.archivo_salida), "%s/%s.%s.%s%s.bmp",
            config.carpeta_salida, basename(config.archivo_entrada),
            config.nombre_filtro,  C_ASM( (&config) ), config.extra_archivo_salida );

    if (config.nombre) {
        printf("%s\n", basename(config.archivo_salida));
        return 0;
    }

    filtro_t *filtro = detectar_filtro(&config);

    filtro->leer_params(&config, argc, argv);
    correr_filtro_imagen(&config, filtro->aplicador);
    filtro->liberar(&config);

    return 0;
}

filtro_t* detectar_filtro(configuracion_t *config) {
    for (int i = 0; filtros[i].nombre != 0; i++) {
        if (strcmp(config->nombre_filtro, filtros[i].nombre) == 0)
            return &filtros[i];
    }
    perror("Filtro desconocido\n");
    return NULL; // avoid C warning
}

void imprimir_tiempos_ejecucion(unsigned long long ciclos_totales, unsigned long long ciclos_media, 
                                unsigned long long desvio_estandar, configuracion_t *config) {
    
    printf("Filtro, Implementación, Imagen, Iteraciones, Ciclos Totales, Ciclos por Llamada, Desvío Std\n");
    printf("%s, %s, %s, %d, %llu, %llu, %llu\n", config->nombre_filtro, C_ASM( (config) ), config->archivo_entrada,
                                config->cant_iteraciones, ciclos_totales, ciclos_media, desvio_estandar);
}

void correr_filtro_imagen(configuracion_t *config, aplicador_fn_t aplicador) {
    imagenes_abrir(config);

    unsigned long long start, end;
    unsigned long long total_start, total_end;
    imagenes_flipVertical(&config->src, src_img);
    imagenes_flipVertical(&config->dst, dst_img);
    unsigned long long ciclos_por_iteracion[config->cant_iteraciones];
    unsigned long long ciclos_totales = 0;
    unsigned long long ciclos_media = 0;
    MEDIR_TIEMPO_START(total_start);
    for (int i = 0; i < config->cant_iteraciones; i++) {
            MEDIR_TIEMPO_START(start);
            aplicador(config);
            MEDIR_TIEMPO_STOP(end);
            ciclos_por_iteracion[i] = end - start;
            ciclos_totales += end - start;
    }
    MEDIR_TIEMPO_STOP(total_end);
    ciclos_media = ciclos_totales / config->cant_iteraciones;
    unsigned long long error_cuadratico = 0;
    for(int i = 0; i < config->cant_iteraciones; ++i){
        long long dif = ciclos_por_iteracion[i] - ciclos_media;
        error_cuadratico += dif * dif;
    }
    error_cuadratico = error_cuadratico / (config->cant_iteraciones == 1? 1 : config->cant_iteraciones - 1);
    unsigned long long desvio_estandar = (unsigned long long) sqrt(error_cuadratico);
    imagenes_flipVertical(&config->dst, dst_img);

    imagenes_guardar(config);
    imagenes_liberar(config);
    imprimir_tiempos_ejecucion(ciclos_totales, ciclos_media, desvio_estandar, config);
}



