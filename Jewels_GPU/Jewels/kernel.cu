#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>
#include <curand.h>
#include <curand_kernel.h>
#include <ctime>

#include <fstream>

//funcion para generar una jewel aleatoria, como la generacion inicial.
/* Funciones para generar gemas aleatorias */
/* Iniciador de seeds */
__global__ void setup_kernel(curandState * state, unsigned long seed)
{
	int id = threadIdx.x;
	curand_init(seed, id, 0, &state[id]);
}

/* Crear jewel usando globalState */
__device__ float generate(curandState* globalState, int ind)
{
	curandState localState = globalState[ind];
	float RANDOM = curand_uniform(&localState);
	globalState[ind] = localState;
	return RANDOM;
}

/* Funcion para generarJewel en CUDA */
__device__ int generarJewelCUDA(curandState* globalState, int ind, int dificultad)
{
	switch (dificultad) {
	case 1:
	{
		return (int)1 + generate(globalState, ind) * 4;
	}
	case 2: {
		return (int)1 + generate(globalState, ind) * 6;
	}
	case 3: {
		return (int)1 + generate(globalState, ind) * 8;
	}
	}
	return -1;
}

/* Funcion para inicializar la matriz de gemas */
__global__ void generacionInicialRandomJewels(float *tablero, int dificultad, int anchura, int altura, curandState* globalState) {
	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;
	if (tFila < altura)
	{
		if (tColumna < anchura)
		{
			tablero[tFila*anchura + tColumna] = generarJewelCUDA(globalState, tFila * anchura + tColumna, dificultad);
		}
	}
}

/* Funcion para imprimir el tablero en GPU */
void printTablero(float* tablero, int anchura, int altura) {
	for (int i = altura - 1; i >= 0; i--) {
		printf("\n");
		for (int j = 0; j < anchura; j++) {
			printf("%d ", (int)tablero[j + i*anchura]);
		}
	}
	printf("\n");
}

//TODO VERTICAL
/*__global__ void eliminarJewelsKernel(float* tablero_d, float* jewels_eliminadas_d, int dificultad, int anchura, int altura, int final) {
	//int ty = threadIdx.x + jewels_eliminadas_d[1];
	//int tx = threadIdx.y + jewels_eliminadas_d[0];
	int tx = threadIdx.y;

	printf("\ntx:%i\n",tx);

	printf("\n eliminadas jewels _Device -> ");
	for (int q = 0; q < final; q++) {
		printf("%f |", jewels_eliminadas_d[q]);
	}
	printf("\n");

	//Horizontal
	if (jewels_eliminadas_d[0] != jewels_eliminadas_d[2]) {
		int posicion_abajo = jewels_eliminadas_d[tx * 2] + (jewels_eliminadas_d[(tx * 2) + 1] - 1) * anchura;
		int posicion = jewels_eliminadas_d[tx * 2] + (jewels_eliminadas_d[(tx * 2) + 1]) * anchura;

		printf("\ntx*2:%i  tx*2+1:%i\n", tx * 2, tx * 2 + 1);
		printf("\nposiciones x:%f y:%f\n", jewels_eliminadas_d[tx * 2], jewels_eliminadas_d[tx * 2 + 1]);

		if (jewels_eliminadas_d[(tx * 2) + 1]-1 < altura) {
			tablero_d[posicion_abajo] = tablero_d[posicion];
			tablero_d[posicion] = -1;
		}
		else {
			if (jewels_eliminadas_d[(tx * 2) + 1]-1 == altura) {
				tablero_d[posicion_abajo] = -1;
			}
		}
	}//Vertical
	else {
		int posicion_arriba = jewels_eliminadas_d[tx * 2] + (jewels_eliminadas_d[(tx * 2) + 1] - 1 + final/2) * anchura;
		int posicion = jewels_eliminadas_d[tx * 2] + (jewels_eliminadas_d[(tx * 2)+1] - 1) * anchura;

		if (jewels_eliminadas_d[(tx * 2) + 1] - 1 + final / 2 < altura) {
			tablero_d[posicion] = tablero_d[posicion_arriba];
			tablero_d[posicion_arriba] = -1;
		}
		else {
			if (jewels_eliminadas_d[(tx * 2) + 1] == altura - 1)
				jewels_eliminadas_d[(tx * 2) + 1] == -1;
		}

		//float value = tablero_d[tx + (ty)*anchura];
		//tablero_d[tx + (ty - final / 2)*(anchura)] = value;
		//tablero_d[tx + (ty)*anchura] = -1;
	}

	//tablero_d[tx+(ty-1)*anchura]=tablero_d[tx + ty*anchura];
	//tablero_d[tx + ty*anchura] = -1;
}*/

//TODO: Se pisan las filas entre ellas al no ir en orden.
/*__global__ void eliminarJewelsKernel(float* tablero_d, float* jewels_eliminadas_d,int dificultad, int anchura, int altura, int final) {
	int tx = threadIdx.x + jewels_eliminadas_d[0];
	int ty = blockIdx.y + jewels_eliminadas_d[1];
	printf("\nBidx x:%i y:%i  | thrdIdx x:%i y:%i\n",blockIdx.x,blockIdx.y,threadIdx.x,threadIdx.y);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	printf("\nFinal: %i\n", final);

	if (jewels_eliminadas_d[0] != jewels_eliminadas_d[2]) {
		//for (int y = jewels_eliminadas_d[1]; y < altura; y++) {
			//printf("A");
			//for (int x = jewels_eliminadas_d[0]; x <= jewels_eliminadas_d[final - 2]; x++) {
				printf("\THREAD X:%i  Y:%i\n", tx, ty);
				if (ty + 1 < altura) {
					//if ty + 1 == altura
					float value = tablero_d[tx + (ty + 1)*anchura];

					__syncthreads();

					tablero_d[tx + (ty)*(anchura)] = value;

					__syncthreads();

					tablero_d[tx + (ty + 1)*anchura] = -1;
				}
				else {
						//tablero_d[tx + ty*anchura] = -2;
				}
		//	}
	//	}
	}
	else {
		//for (int y = jewels_eliminadas_d[1]; y < altura; y++) {
			//printf("A");
			//for (int x = jewels_eliminadas_d[0]; x <= jewels_eliminadas_d[final - 2]; x++) {
				//printf("\nBUCLE X:%i  Y:%i\n", x, y);
				if (ty < altura) {
					if (ty >= jewels_eliminadas_d[final - 2]) {
						float value = tablero_d[tx + (ty)*anchura];
						tablero_d[tx + (ty - final / 2)*(anchura)] = value;
						tablero_d[tx + (ty)*anchura] = -1;
					}
					else {
						tablero_d[tx + (ty)*anchura] = -1;
					}
				}
			//}
		//}
	}

	/*if (altura >= anchura) max = altura;
	else max = anchura;
	printf("\nJewels a eliminar: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas_d[0], jewels_eliminadas_d[1] / anchura, jewels_eliminadas_d[2], jewels_eliminadas_d[3] / anchura, jewels_eliminadas_d[4], jewels_eliminadas_d[5] / anchura);

	for (int i = 0; i < max; i++) {
		if ((tx == jewels_eliminadas_d[i]) && (ty)>(jewels_eliminadas_d[i + 1])) {
			tablero_d[tx + (ty - 1)*(anchura)] = tablero_d[tx + ty*anchura];
		}

		if (ty == altura) {
			//Generar jewel random
			curandState state;

			curand_init((unsigned long long)clock(), i, 0, &state);

			tablero_d[tx + ty*anchura] = curand_uniform(&state);
		}
		i++;
	}*
}*/

//Elimina las jewels recibidas, bajas las filas para rellenas, y genera arriba del todo jewels nuevas. TODO
/*void eliminarJewels(float* tablero, float* jewels_eliminadas,int dificultad, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	float *aux;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	aux = (float*)malloc(2 * max * sizeof(float));

	for (int i = 0; i < 2*max; i++) {
		aux[i]=jewels_eliminadas[i];
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, 2 * max * sizeof(float));

	//for (int y = jewels_eliminadas_d[1]; y < altura; y++) {
	//for (int x = jewels_eliminadas_d[0]; x <= jewels_eliminadas_d[final - 2]; x++) {
	int final = 0;

	for (int i = 0; i < max * 2; i++) {
		printf("\ni:%i valor:%f\n", i, jewels_eliminadas[i]);
		if (jewels_eliminadas[i] < 0) {
			final = i;
			break;
		}
	}

	if (final == 0) final = max * 2;

	//Configuracion de ejecucion, 1 bloque por fila con tantos hilos como columnas
	//dim3 dimBlock(altura-jewels_eliminadas[1]-1,1);
	//dim3 dimGrid(1,jewels_eliminadas[final - 2] - jewels_eliminadas[0] + 1);

	//nº de bloques
	dim3 dimGrid(1,1);

	printf("\nfinal: %i\n",final);
	printf("\n");
	for (int w = 0; w < final; w++) {
		printf("%f |",aux[w]);
	}
	printf("\n");

	if(aux[0]>=0)
	for (int z = 1; z <= altura-aux[1]-1; z++) {
		printf("\nantes buc k <= %f\n", aux[final - 2] - aux[0]);
		for (int k = 0; k < final; k+=2) {
			jewels_eliminadas[k] = aux[k];
			jewels_eliminadas[k + 1] = aux[k + 1] + z;
			printf("\nañadido a eliminadas x:%f y:%f\n",aux[k],aux[k+1]+z);
		}

		printf("\n eliminadas jewels -> ");
		for (int q = 0; q < final; q++) {
			printf("%f |", jewels_eliminadas[q]);
		}
		printf("\n");

		//Inicio del calculo, misma funcion de analisis en manual y automatico
		cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, 2 * max * sizeof(float), cudaMemcpyHostToDevice);

		if (jewels_eliminadas[1] == jewels_eliminadas[3]) {
			dim3 dimBlock(1, jewels_eliminadas[final - 2] - jewels_eliminadas[0] + 1);
			eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, jewels_eliminadas_d, dificultad, anchura, altura, final);
		}
		else {
			dim3 dimBlock(altura - jewels_eliminadas[1] + 1, 1);
			eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, jewels_eliminadas_d, dificultad, anchura, altura, final);
		}
		printf("\nLLAMADA\n");

		//Transfiere las jewels a eliminar de la GPU al host
		cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

	}

	srand(time(NULL));
	switch (dificultad) {
	case 1: {
		int randJewel = rand() % 4 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	case 2: {
		int randJewel = rand() % 6 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	case 3: {
		int randJewel = rand() % 8 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	}

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
}*/

__global__ void eliminarJewelsKernel(float* tablero_d, float* tablero_aux_d, float* jewels_eliminadas_d, int dificultad, int anchura, int altura, int final) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	//printf("\nBidx x:%i y:%i  | thrdIdx x:%i y:%i\n", blockIdx.x, blockIdx.y, threadIdx.x, threadIdx.y);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//printf("\nFinal: %i\n", final);

	if (jewels_eliminadas_d[0] != jewels_eliminadas_d[2] && tx >= jewels_eliminadas_d[0] && tx <= jewels_eliminadas_d[final - 2] && ty >= jewels_eliminadas_d[1]) {
		//printf("\THREAD X:%i  Y:%i\n", tx, ty);
		if (ty + 1 < altura) {
			float value = tablero_aux_d[tx + (ty + 1)*anchura];

			//printf("\nvalue: %f\n",value);

			tablero_d[tx + (ty)*(anchura)] = value;

			//tablero_d[tx + (ty + 1)*anchura] = -1;
		}
		else {
			//printf("\nFin\n");
			tablero_d[tx + ty*anchura] = -1;
		}
	}
	else {
		if (ty < altura && tx == jewels_eliminadas_d[0] && ty > jewels_eliminadas_d[1]) {
			float value = tablero_aux_d[tx + (ty)*anchura];
			tablero_d[tx + (ty - final / 2)*(anchura)] = value;
			//tablero_d[tx + (ty)*anchura] = -1;
		}
		if (ty >= altura - final / 2 && ty < altura && tx == jewels_eliminadas_d[0]) {
			tablero_d[tx + (ty)*anchura] = -1;
		}
	}
}

void eliminarJewels(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	float *tablero_aux_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);
	cudaMalloc((void**)&tablero_aux_d, size);
	cudaMemcpy(tablero_aux_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, 2 * max * sizeof(float));

	dim3 dimGrid(1, 1);
	dim3 dimBlock(anchura, altura);
	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, 2 * max * sizeof(float), cudaMemcpyHostToDevice);

	int final = 0;

	for (int i = 0; i < max * 2; i++) {
		printf("\ni:%i valor:%f\n", i, jewels_eliminadas[i]);
		if (jewels_eliminadas[i] < 0) {
			final = i;
			break;
		}
	}

	if (final == 0) final = max * 2;

	eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, tablero_aux_d, jewels_eliminadas_d, dificultad, anchura, altura, final);

	cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

	for (int k = 0; k < size; k++) {
		if (tablero[k] == -1) {
			srand(time(NULL));
			switch (dificultad) {
			case 1: {
				int randJewel = rand() % 4 + 1;
				tablero[k] = randJewel;
				break;
			}
			case 2: {
				int randJewel = rand() % 6 + 1;
				tablero[k] = randJewel;
				break;
			}
			case 3: {
				int randJewel = rand() % 8 + 1;
				tablero[k] = randJewel;
				break;
			}
			};
		}
	}

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
	cudaFree(tablero_aux_d);
}

/*void eliminarJewels(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	float *aux;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	aux = (float*)malloc(2 * max * sizeof(float));

	for (int i = 0; i < 2 * max; i++) {
		aux[i] = jewels_eliminadas[i];
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, 2 * max * sizeof(float));

	//for (int y = jewels_eliminadas_d[1]; y < altura; y++) {
	//for (int x = jewels_eliminadas_d[0]; x <= jewels_eliminadas_d[final - 2]; x++) {
	int final = 0;

	for (int i = 0; i < max * 2; i++) {
		printf("\ni:%i valor:%f\n", i, jewels_eliminadas[i]);
		if (jewels_eliminadas[i] < 0) {
			final = i;
			break;
		}
	}

	if (final == 0) final = max * 2;

	//Configuracion de ejecucion, 1 bloque por fila con tantos hilos como columnas
	//dim3 dimBlock(altura-jewels_eliminadas[1]-1,1);
	//dim3 dimGrid(1,jewels_eliminadas[final - 2] - jewels_eliminadas[0] + 1);

	//nº de bloques
	dim3 dimGrid(1, 1);

	printf("\nfinal: %i\n", final);
	printf("\n");
	for (int w = 0; w < final; w++) {
		printf("%f |", aux[w]);
	}
	printf("\n");

	if (aux[0] >= 0)
		for (int z = 1; z <= altura - aux[1] - 1; z++) {
			printf("\nantes buc k <= %f\n", aux[final - 2] - aux[0]);
			for (int k = 0; k < final; k += 2) {
				jewels_eliminadas[k] = aux[k];
				jewels_eliminadas[k + 1] = aux[k + 1] + z;
				printf("\nañadido a eliminadas x:%f y:%f\n", aux[k], aux[k + 1] + z);
			}

			printf("\n eliminadas jewels -> ");
			for (int q = 0; q < final; q++) {
				printf("%f |", jewels_eliminadas[q]);
			}
			printf("\n");

			//Inicio del calculo, misma funcion de analisis en manual y automatico
			cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, 2 * max * sizeof(float), cudaMemcpyHostToDevice);

			if (jewels_eliminadas[1] == jewels_eliminadas[3]) {
				dim3 dimBlock(1, jewels_eliminadas[final - 2] - jewels_eliminadas[0] + 1);
				eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, jewels_eliminadas_d, dificultad, anchura, altura, final);
			}
			else {
				dim3 dimBlock(altura - jewels_eliminadas[1] + 1, 1);
				eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, jewels_eliminadas_d, dificultad, anchura, altura, final);
			}
			printf("\nLLAMADA\n");

			//Transfiere las jewels a eliminar de la GPU al host
			cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

		}

	srand(time(NULL));
	switch (dificultad) {
	case 1: {
		int randJewel = rand() % 4 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	case 2: {
		int randJewel = rand() % 6 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	case 3: {
		int randJewel = rand() % 8 + 1;
		tablero_d[tx + (ty + 1)*anchura] = randJewel;
		break;
	}
	}

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
}*/

__global__ void analisisTableroAutomaticoKernel(float *tablero_d, float *aux_d, int dificultad, int anchura, int altura) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	int jewels_posibles_der = 0;

	//Si tiene por la derecha
	if ((tx + 2) < anchura) {
		if (((tx + 2) + ty*anchura <= altura*anchura) && tablero_d[tx + 2 + ty*anchura] == tablero_d[tx + ty*anchura]) {
			int i = 2;
			while ((tx + i + ty*anchura <= altura*anchura) && tablero_d[tx + i + ty*anchura] == tablero_d[tx + ty*anchura]) {
				jewels_posibles_der++;
				i++;
			}

			aux_d[tx + ty*anchura] = jewels_posibles_der + 1;
		}
		else {
			aux_d[tx + ty*anchura] = 1;
		}
	}
	else {
		aux_d[tx + ty*anchura] = 1;
	}
}

void analisisTableroManual(int dificultad, float* tablero, int anchura, int altura, int x, int y) {
	int max = 0;
	int size = anchura*altura;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan MAX jewels como mucho, se guardan sus x e y
	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	int jewels_posibles_izq = 0;
	int jewels_posibles_der = 0;
	//printf("\nHORIZONTAL\n");
	//Si tiene por la izquierda
	if ((x - 1 + y*anchura >= 0) && tablero[x - 1 + y*anchura] == tablero[x + y*anchura]) {
		int i = 1;
		while ((x - i + y*anchura >= 0) && (x - i >= 0) && tablero[x - i + y*anchura] == tablero[x + y*anchura]) {
			jewels_posibles_izq++;
			i++;
		}
	}

	//Si tiene por la derecha
	if ((x + 1 + y*anchura <= size) && tablero[x + 1 + y*anchura] == tablero[x + y*anchura]) {
		int i = 1;
		while ((x + i + y*anchura <= size) && (x + i < anchura) && tablero[x + i + y*anchura] == tablero[x + y*anchura]) {
			jewels_posibles_der++;
			i++;
		}
	}

	//Se pueden eliminar horizontalmente
	if (1 + jewels_posibles_izq + jewels_posibles_der >= 3) {
		int salto = 0;

		//printf("\nIZQ:%i   DER:%i\n",jewels_posibles_izq,jewels_posibles_der);

		for (int j = jewels_posibles_izq; j >= (1); j--) {
			jewels_eliminadas[salto] = x - j;
			jewels_eliminadas[salto + 1] = y;
			salto += 2;
		}

		jewels_eliminadas[jewels_posibles_izq * 2] = x;
		jewels_eliminadas[jewels_posibles_izq * 2 + 1] = y;

		salto = 2;
		for (int k = 1; k <= jewels_posibles_der; k++) {
			jewels_eliminadas[salto + jewels_posibles_izq * 2] = x + k;
			jewels_eliminadas[salto + jewels_posibles_izq * 2 + 1] = y;
			salto += 2;
		}
	}
	else {	//Analizamos la vertical
		int jewels_posibles_arrib = 0;
		int jewels_posibles_abaj = 0;

		//printf("\nVERTICAL\n");
		//Si tiene por abajo
		if ((x + (y - 1)*anchura >= 0) && tablero[x + (y - 1)*anchura] == tablero[x + y*anchura]) {
			printf("\nABAJO\n");
			int i = 1;
			while ((x + (y - i)*anchura >= 0) && tablero[x + (y - i)*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_abaj++;
				//printf("\nTIENE ABAJO\n");
				i++;
			}
		}

		//Si tiene por arriba
		if ((x + 1 + y*anchura <= size) && tablero[x + (y + 1)*anchura] == tablero[x + y*anchura]) {
			//printf("\nARRIBA\n");
			int i = 1;
			while ((x + (y + i)*anchura <= size) && tablero[x + (y + i)*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_arrib++;
				//printf("\nTIENE ARRIBA\n");
				i++;
			}
		}

		//Se pueden eliminar
		if (1 + jewels_posibles_abaj + jewels_posibles_arrib >= 3) {
			//printf("\nSE PUEDE\n");

			int salto = 0;
			for (int j = jewels_posibles_abaj; j >= (1); j--) {
				jewels_eliminadas[salto] = x;
				jewels_eliminadas[salto + 1] = y - j;
				salto += 2;
			}

			jewels_eliminadas[jewels_posibles_abaj * 2] = x;
			jewels_eliminadas[jewels_posibles_abaj * 2 + 1] = y;

			salto = 2;
			for (int k = 1; k <= jewels_posibles_arrib; k++) {
				jewels_eliminadas[salto + jewels_posibles_abaj * 2] = x;
				jewels_eliminadas[salto + jewels_posibles_abaj * 2 + 1] = y + k;
				salto += 2;
			}
		}
	}

	for (int q = 0; q < 2 * max; q++) {
		if (q % 2 != 0) {
			printf(" y:%f\n", jewels_eliminadas[q]);
		}
		else {
			printf("| x:%f\n", jewels_eliminadas[q]);
		}
	}
	eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura);
}

void intercambiarPosiciones(float* tablero, int jewel1_x, int jewel1_y, int direccion, int anchura, int altura, int seleccion, int dificultad) {
	int jewel2_x = jewel1_x;
	int jewel2_y = jewel1_y;
	switch (direccion)
	{
	case 1: //Arriba
	{
		jewel2_y += 1;
		break;
	}
	case 2: //Abajo
	{
		jewel2_y -= 1;
		break;
	}
	case 3: //Izquierda
	{
		jewel2_x -= 1;
		break;
	}
	case 4: //Derecha
	{
		jewel2_x += 1;
		break;
	}
	}
	int aux1;

	aux1 = tablero[jewel2_x + jewel2_y*anchura];

	tablero[jewel2_x + jewel2_y*anchura] = tablero[jewel1_x + jewel1_y*anchura];
	tablero[jewel1_x + jewel1_y*anchura] = aux1;

	analisisTableroManual(dificultad, tablero, anchura, altura, jewel2_x, jewel2_y);
}

//CUDA CPU Function. Analiza la mejor opcion y la ejecuta
void analisisTableroAutomatico(int dificultad, float* tablero, int anchura, int altura) {
	float *tablero_d;
	float *aux_d;
	float *aux;
	float *jewels_eliminadas_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan 3 jewels, 2 coordenadas por jewel = 6 posiciones en el array
	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));
	aux = (float*)malloc(size);

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	for (int p = 0; p < size; p++) {
		aux[p] = 1;
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);
	cudaMalloc((void**)&aux_d, size);
	cudaMemcpy(aux_d, aux, size, cudaMemcpyHostToDevice);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del calculo, misma funcion de analisis en manual y automatico
	analisisTableroAutomaticoKernel <<<dimGrid,dimBlock>>> (tablero_d, aux_d, dificultad, anchura, altura);
	if (cudaSuccess != cudaGetLastError())
		printf("\nCUDA Error!\n");

	//Transfiere las jewels a eliminar de la GPU al host
	cudaMemcpy(aux, aux_d, size, cudaMemcpyDeviceToHost);

	printTablero(aux, anchura, altura);

	int x_mejor = 0;
	int y_mejor = 0;
	int valor_mejor = 0;

	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			if (aux[x+y*anchura] > valor_mejor) {
				valor_mejor = aux[x+y*anchura];
				x_mejor = x;
				y_mejor = y;
			}
		}
	}

	if (valor_mejor >= 3) {
		intercambiarPosiciones(tablero, x_mejor, y_mejor, 4, anchura, altura, 1, dificultad);
	}
}

/* Funcion que carga del archivo la anchura, altura y dificultad del tablero */
bool precargar(int& anchura, int& altura, int& dificultad, char* fichero)
{
	std::ifstream fCarga(fichero);
	char tam[4];
	if (!fCarga.is_open())
	{
		std::cout << "ERROR: no existe un archivo guardado." << std::endl;
		return false;
	}

	fCarga.getline(tam, 4);

	anchura = (int)tam[0] - 48;
	altura = (int)tam[1] - 48;
	dificultad = (int)tam[2] - 48;

	fCarga.close();
	return true;
}

/* Funcion que carga el tablero guardado previamente */
void cargar(int anchura, int altura, float*  tablero, char* fichero)
{
	char* array = (char*)malloc(anchura*altura + 1 + 3);
	std::ifstream fCarga(fichero);
	fCarga.getline(array, (anchura*altura + 1 + 3));
	for (int i = 0; i < anchura*altura; i++)
	{
		tablero[i] = array[i + 3] - 48;
	}
	free(array);
	fCarga.close();
}

/* Funcion que guarda el tablero */
void guardado(float* tablero, int anchura, int altura, int dificultad, char* fichero)
{
	//Sistema de guardado
	std::ofstream ficheroGuardado;
	ficheroGuardado.open(fichero);
	ficheroGuardado.clear();
	/* Almacenar anchura y altura*/
	ficheroGuardado << anchura;
	ficheroGuardado << altura;
	ficheroGuardado << dificultad;
	/* Almacenar Resto */
	for (int index = 0; index < anchura*altura; index++)
	{
		ficheroGuardado << tablero[index];
	}
	ficheroGuardado.close();
}

/* Funcion que elimina una fila */
__global__ void bombaFila(float* tablero, int anchura, int altura, int dificultad, int fila, curandState* globalState) {

	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;

	if ((tFila + fila) < altura)
	{
		if (tColumna < anchura)
		{
			if ((tFila + fila + 1) == altura)
			{
				tablero[(tFila + fila)*anchura + tColumna] = generarJewelCUDA(globalState, (tFila * 3 + tColumna), dificultad);
			}
			else {
				tablero[(tFila + fila)*anchura + tColumna] = tablero[(tFila + fila + 1)*anchura + tColumna];

			}
		}
	}
}

/* Funcion que elimina una columna */
__global__ void bombaColumna(float* tablero, int anchura, int altura, int dificultad, int columna, curandState* globalState) {

	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;

	if (tFila < altura)
	{
		if ((tColumna + columna) < anchura)
		{
			if ((tColumna + columna + 1) == anchura)
			{
				tablero[(tFila*anchura) + (tColumna + columna)] = generarJewelCUDA(globalState, (tFila * 3 + tColumna), dificultad);
			}
			else {
				tablero[(tFila*anchura) + (tColumna + columna)] = tablero[(tFila*anchura) + (tColumna + columna + 1)];
			}
		}
	}
}

__global__ void bombaRotarGPU1(float* tablero, int anchura, int altura)
{
	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;
	int fila = -1, columna = -1;
	float aux[9];

	if (tFila < altura)	{
		if (tColumna < anchura)	{
			if ((tFila - 1) < 0 || (tFila + 1) >= altura || (tColumna - 1) < 0 || (tColumna + 1) >= anchura) {}
			else {
				if (tFila*anchura + tColumna % 4 == 1) {
					fila = tFila;
					columna = tColumna;
				}
				if (fila != -1 && columna != -1)
				{
					aux[tFila * 3 + tColumna] = tablero[((fila + 1) - tFila) + ((columna + 1) - tColumna)*altura];
					printf("%f", aux[tFila * 3 + tColumna]);
					tablero[((fila + 1) - tFila)*anchura + ((columna - 1) + tColumna)] = aux[tFila * 3 + tColumna];
				}
			}
		}
	}
}

__global__ void bombaRotarGPU(float* tablero, int anchura, int altura, int fila, int columna)
{
	float aux[9];
	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;

	if (tFila < 3)
	{
		if (tColumna < 3)
		{
			aux[tFila + tColumna * 3] = tablero[((fila + 1) - tFila) *anchura + ((columna + 1) - tColumna)];
			printf("%i-%i ", tFila + tColumna * 3, aux[tFila+tColumna*3]);
			tablero[((fila + 1) - tFila)*anchura + ((columna - 1) + tColumna)] = aux[tFila * 3 + tColumna];
			printf("%i_%i ", ((fila + 1) - tFila)*anchura + ((columna - 1) + tColumna), tFila * 3 + tColumna);
		}
	}
}

__global__ void bombaRotar(float* tablero_d, int anchura, int altura)
{
	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;
	if (tFila < altura && tColumna < anchura) {
		if ((tFila - 1) < 0 || (tFila + 1) >= altura || (tColumna - 1) < 0 || (tColumna + 1) >= anchura)
		{
			/* Se entra cuando no se puede rotar */

		}
		else
		{
			if (tFila % 3 == 1 && tColumna % 3 == 1)
			{
				dim3 dimBlock(3, 3);
				dim3 dimGrid(1, 1);
				
				bombaRotarGPU << <dimGrid, dimBlock >> >(tablero_d, anchura, altura, tFila, tColumna);
				//__syncthreads();
			}
		}
	}
}

int main(int argc, char** argv) {
	//Matriz de tamaño variable de floats, un array de Altura*Anchura
	int anchura, altura, dificultad, size, seleccion;
	int jewel1_x, jewel1_y, accion;
	char modo, ficheroGuardado[9] = "save.txt";;
	bool automatico = true;
	bool encontrado = false;
	bool jugando = true;
	float* tablero;
	float* tablero_d;

	curandState* devStates;

	/* Valores por argumento/
	modo = argv[1][1];
	dificultad = atoi(argv[2]);
	anchura = atoi(argv[3]);
	altura = atoi(argv[4]);*/

	modo = 'a';
	dificultad = 3;
	anchura = 6;
	altura = 3;
	size = anchura*altura;

	/* Establecer modo de juego */
	switch (modo) {
	case 'a': {seleccion = 1; break; }
	case 'm': {seleccion = 2; break; }
	default: printf("Valor no valido.\n"); return -1;
	}

	/* Inicializacion random en CUDA */
	cudaMalloc(&devStates, size * sizeof(curandState));
	/* Creacion de las Seeds */
	setup_kernel << < 1, size >> > (devStates, unsigned(time(NULL)));

	/* Reservar memoria para tablero y tablero_d */
	tablero = (float*)malloc(size * sizeof(float));
	cudaMalloc((void**)&tablero_d, size * sizeof(float));

	/* Inicializacion de la Matriz en CUDA*/
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);
	generacionInicialRandomJewels << < dimGrid, dimBlock >> > (tablero_d, dificultad, anchura, altura, devStates);
	cudaMemcpy(tablero, tablero_d, size * sizeof(float), cudaMemcpyDeviceToHost);

	//Bucle principal del juego
	while (jugando) {

		printTablero(tablero, anchura, altura);

		jewel1_x = 0;
		jewel1_y = 0;
		accion = 0;

		std::cout << "Acción a realizar:\n";
		std::cout << "(1) Intercambiar Jewels\n";
		std::cout << "(2) Guardar partida\n";
		std::cout << "(3) Cargar partida\n";
		std::cout << "(9) Usar una Bomba\n";
		std::cout << "(0) Exit\n";
		std::cout << "Elija accion: ";

		std::cin >> accion;

		switch (accion) {
		/* Salir*/
		case 0: {
			goto Salir;
			break;
		}
		/* Intercambio */
		case 1: {

			std::cout << "Posicion de la primera jewel a intercambiar (empiezan en 0)\n";
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
			else {
				switch (direccion)
				{
				case 1: //Arriba
				{
					if (jewel1_y == altura)
					{
						printf("No se puede realizar el intercambio especificado.\n");
						continue;
					}
					break;
				}
				case 2: //Abajo
				{
					if (jewel1_y == 0)
					{
						printf("No se puede realizar el intercambio especificado.\n");
						continue;
					}
					break;
				}
				case 3: //Izquierda
				{
					if (jewel1_x == 0)
					{
						printf("No se puede realizar el intercambio especificado.\n");
						continue;
					}
					break;
				}
				case 4: //Derecha
				{
					if (jewel1_x == anchura - 1)
					{
						printf("No se puede realizar el intercambio especificado.\n");
						continue;
					}
					break;
				}
				}

				intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion, anchura, altura, seleccion, dificultad);

				if (seleccion == 1)
					analisisTableroAutomatico(dificultad, tablero, anchura, altura);
			}

			break;
		}
		/* Guardar tablero */
		case 2: {
			guardado(tablero, anchura, altura, dificultad, ficheroGuardado);
			std::cout << "Guardado correcto.\n";
			break;
		}
		/* Cargar tablero */
		case 3: {
			/* Precarga de tablero */
			encontrado = precargar(anchura, altura, dificultad, ficheroGuardado);

			if (encontrado)
			{
				/* Cargar tablero */
				cargar(anchura, altura, tablero, ficheroGuardado);
				std::cout << "Se ha cargado el Tablero: \n";
			}
			else {
				std::cout << "No existe ninguna partida guardada.\n";
			}
			break;

		}
		/* Usar Bombas */
		case 9: {
			int bomba = 0, fila = 0, columna = 0;
			std::cout << "Elija una bomba:";

			/* CUDA */
			dim3 blockDim(anchura, altura);
			dim3 blockGrid(1, 1);
			cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);

			/* Bombas por tipo de dificultad */
			switch (dificultad) {
			/* Dificultad 1 */
			case 1: {
				std::cout << "\n(1) Bomba de fila ";
				std::cout << "\nEleccion: ";
				std::cin >> bomba;

				if (bomba != 1)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				std::cout << "Fila: ";
				std::cin >> fila;
				bombaFila << < dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
				break;
			}
			/* Dificultad 2 */
			case 2: {
				std::cout << "\n(1) Bomba de fila";
				std::cout << "\n(2) Bomba de columna";
				std::cout << "\nEleccion: ";
				std::cin >> bomba;

				if (bomba < 1 && bomba > 2)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				switch (bomba) {
				case 1:
				{
					std::cout << "Fila: ";
					std::cin >> fila;
					bombaFila << < dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
					break;
				}
				case 2:
				{
					std::cout << "Columna: ";
					std::cin >> columna;
					bombaColumna << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, columna, devStates);
					break;
				}
				}
				break;
			}
			/* Dificultad 3 */
			case 3: {
				std::cout << "\n(1) Bomba de fila";
				std::cout << "\n(2) Bomba de columna";
				std::cout << "\n(3) Bomba de rotacion 3x3";
				std::cout << "\nEleccion: ";
				std::cin >> bomba;

				if (bomba < 1 && bomba > 3)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				switch (bomba) {
				case 1:
				{
					std::cout << "Fila: ";
					std::cin >> fila;
					bombaFila << < dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
					break;
				}
				case 2:
				{
					std::cout << "Columna: ";
					std::cin >> columna;
					bombaColumna << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, columna, devStates);
					break;
				}
				case 3: 
				{
					for (int fila = 1; fila < anchura; fila += 3)
					{
						for (int columna = 1; columna < altura; columna += 3)
						{
							if ((fila - 1) < 0 || (fila + 1) >= altura || (columna - 1) < 0 || (columna + 1) >= anchura)
							{
								/* Se entra cuando no se puede rotar */
							}
							else
							{
								dim3 blockGrid(anchura/3, altura/3);
								bombaRotar << < dimGrid, dimBlock >> > (tablero_d, anchura, altura);
							}
						}
					}
					break;
				}
				}

				break;
			}
			}
			/* Actualizar Tablero */
			cudaMemcpy(tablero, tablero_d, size * sizeof(float), cudaMemcpyDeviceToHost);
			break;
		}
		}
	}

Salir:
	free(tablero);
	cudaFree(tablero_d);
	cudaFree(devStates);
	return 0;
}