#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>

//Función que llamara a la de CUDA para actualizar la matrz
void deleteJewels(float *A, int width) {
	//int size = width*width * sizeof(float);
	//float *A_d, *B_d, *C_d;

	//A y B a memoria GPU
	/*cudaMalloc((void**)&A_d, size);
	cudaMemcpy(A_d, A, size, cudaMemcpyHostToDevice);
	cudaMalloc((void**)&B_d, size);
	cudaMemcpy(B_d, B, size, cudaMemcpyHostToDevice);

	//Malloc en GPU de C
	cudaMalloc((void**)&C_d, size);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(width, width);
	dim3 dimGrid(1, 1);

	//Inicio del calculo
	//Kernel << <dimGrid, dimBlock >> >(A_d, B_d, C_d, width);

	//Transfiere la solucion de la GPU al host
	cudaMemcpy(C, C_d, size, cudaMemcpyDeviceToHost);

	//Libera memoria
	cudaFree(A_d);
	cudaFree(B_d);
	cudaFree(C_d);*/
}

void generacionInicialRandomJewels(float *tablero, int dificultad, int altura, int anchura) {
	for (int i = 0; i < altura*anchura; i++) {

	}
}

int main() {
	//Matriz de tamaño variable de floats, un array de Altura*Anchura
	int anchura = 2;
	int altura = 2;
	int dificultad = 1;
	int TILE_WIDTH = 16;

	float *tablero;
	bool jugando = true;

	std::cout << "Altura del tablero: ";
	std::cin >> altura;

	std::cout << "Anchura del tablero: ";
	std::cin >> anchura;

	std::cout << "Elija dificultad: \n1.-Facil \n2.-Media \n3.-Dificil";
	std::cin >> dificultad;

	tablero = (float*)malloc(altura * anchura * sizeof(float));

	//Se inicializa la matriz
	generacionInicialRandomJewels(tablero, dificultad, altura, anchura);


	//Bucle principal del juego
	while (jugando) {

	}

	/*const int width = 3;
	float A[width*width], B[width*width], C[width*width];
	for (int i = 0; i < (width*width); i++) {
		int valor = 0;
		std::cout << "Valor en A (de izquierda a derecha, por filas): ";
		std::cin >> valor;
		A[i] = valor;
		valor = 0;
		std::cout << "Valor en B (de izquierda a derecha, por filas): ";
		std::cin >> valor;
		B[i] = valor;
		C[i] = 0;
	}
	MatrixMultiplication(A, B, C, width);
	printf("Solucion: \n");
	for (int i = 0; i < (width*width); i++) {
		if (i%width == 0) { printf("\n"); }
		printf("%f ", C[i]);
	}

	int exit;
	scanf("%d", &exit);*/

	return 0;
}