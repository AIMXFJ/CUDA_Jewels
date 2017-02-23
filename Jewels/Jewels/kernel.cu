#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>

//Función que llamara a la de CUDA para actualizar la matrz
//void deleteJewels(float *A, int width) {
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
//}

//funcion para generar una jewel aleatoria, como la generacion inicial.
int generarJewel(int dificultad) {
	switch (dificultad) {
	case 1: {
		int randJewel = rand() % 4 + 1;
		return randJewel;
		break;
	}
	case 2: {
		int randJewel = rand() % 6 + 1;
		return randJewel;
		break;
	}
	case 3: {
		int randJewel = rand() % 8 + 1;
		return randJewel;
		break;
	}
	}
}

void generacionInicialRandomJewels(float *tablero, int dificultad, int anchura, int altura) {
	for (int i = 0; i < altura*anchura; i++) {
		switch (dificultad) {
		case 1: {
			int randJewel = rand() % 4 + 1;
			tablero[i] = randJewel;
			break;
			}
		case 2: {
			int randJewel = rand() % 6 + 1;
			tablero[i] = randJewel;
			break;
			}
		case 3: {
			int randJewel = rand() % 8 + 1;
			tablero[i] = randJewel;
			break;
		}
		}
	}
}

void printTablero(float* tablero, int anchura, int altura) {
	for (int i = 0; i < altura*anchura; i++) {
		if (i%anchura == 0)
			printf("\n");
		printf("%d ",(int)tablero[i]);
	}
}

//Elimina las jewels recibidas, bajas las filas para rellenas, y genera arriba del todo jewels nuevas. TODO
void eliminarJewels() {

}

//CUDA CPU Function
void analisisTableroManual(int dificultad, float* tablero[], int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	int size = anchura * altura * sizeof(float);

	//Solo se eliminan 3 jewels, 2 coordenadas por jewel = 6 posiciones en el array
	float* jewels_eliminadas = (float*)malloc(6 * sizeof(float));

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, 6 * sizeof(float));
	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, 6 * sizeof(float), cudaMemcpyHostToDevice);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del calculo, misma funcion de analisis en manual y automatico
	//analisisTableroKernel << <dimGrid, dimBlock >> >(tablero_d, jewels_eliminadas_d, anchura, altura);

	//Transfiere las jewels a eliminar de la GPU al host
	cudaMemcpy(jewels_eliminadas, jewels_eliminadas_d, size, cudaMemcpyDeviceToHost);

	//Se eliminan las jewels seleccionadas, se bajan las superiores y se generan nuevas
	//eliminarJewels(tablero, jewels_eliminadas, anchura, altura);

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
}

//CUDA CPU Function.
void analisisTableroAutomatico() {

}

//CUDA CPU Function. TODO
void intercambiarPosiciones(float* tablero, int jewel1_x, int jewel1_y, int direccion, int anchura, int altura) {
	int jewel2_x = jewel1_x;
	int jewel2_y = jewel1_y;
	switch (direccion) 
	{
		case 1: 
		{
			if (jewel1_y == 0)
			{
				jewel2_y = altura - 1;
			}
			else
			{
				jewel2_y = jewel1_x - 1;
			}
			break;
		}
		case 2:
		{
			if (jewel1_y == altura - 1 )
			{
				jewel2_y = 0;
			}
			else
			{
				jewel2_y = jewel1_y + 1;
			}
			break;
		}
		case 3:
		{
			if (jewel1_x == 0)
			{
				jewel2_x = anchura - 1;
			}
			else
			{
				jewel2_x = jewel1_x - 1;
			}
			break;
		}
		case 4:
		{
			if (jewel1_x == anchura - 1)
			{
				jewel2_x = 0;
			}
			else
			{
				jewel2_x = jewel1_x + 1;
			}
			break;
		}
	}

	/* CPU mode */
	int aux1;

	aux1 = tablero[(jewel1_x + 1)*(jewel1_y + 1)];

	tablero[(jewel1_x + 1)*(jewel1_y + 1)] = tablero[(jewel2_x + 1)*(jewel2_y + 1)];
	tablero[(jewel2_x + 1)*(jewel2_y + 1)] = aux1;
}

int main() {
	//Matriz de tamaño variable de floats, un array de Altura*Anchura
	int anchura = 2;
	int altura = 2;
	int dificultad = 1;
	bool automatico = true;
	int TILE_WIDTH = 16;

	float *tablero;
	bool jugando = true;

	std::cout << "Anchura del tablero: ";
	std::cin >> anchura;

	std::cout << "Altura del tablero: ";
	std::cin >> altura;

	std::cout << "Elija dificultad: \n1.-Facil \n2.-Media \n3.-Dificil";
	std::cin >> dificultad;

	int seleccion;
	std::cout << "Automatico?   1.-SI   2.-NO";
	std::cin >> seleccion;

	switch (seleccion) {
	case 1: automatico = true; break;
	case 2: automatico = false; break;
	default: printf("Valor no valido.\n"); return -1;
	}

	tablero = (float*)malloc(altura * anchura * sizeof(float));

	//Se inicializa la matriz
	generacionInicialRandomJewels(tablero, dificultad, anchura, altura);

	//Bucle principal del juego
	while (jugando) {
		printTablero(tablero, anchura, altura);
		//analisisTableroManual();

		int jewel1_x = 0;
		int jewel1_y = 0;
		std::cout << "Posicion de la primera jewel (empiezan en 0)\n";
		std::cout << "X: ";
		std::cin >> jewel1_x;
		std::cout << "Y: ";
		std::cin >> jewel1_y;

		if (!((jewel1_x < anchura) && (jewel1_x >= 0) && (jewel1_y < altura) && (jewel1_y >= 0))) {
			printf("Posicion erronea.\n");
			continue;
		}

		int direccion = 0;
		std::cout << "Direccion a seguir para intercambio de posiciones: \n 1.-Arriba\n 2.-Abajo\n 3.-Izquierda\n 4.-Derecha";
		std::cin >> direccion;

		if (direccion > 4 && direccion > 1) {
			printf("Direccion erronea.\n");
			continue;
		}

		intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion,anchura,altura);

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