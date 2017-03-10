#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>
#include <curand.h>
#include <curand_kernel.h>
#include <ctime>

#include <fstream>

//funcion para generar una jewel aleatoria, como la generacion inicial.
int generarJewel(int dificultad) {
	srand(time(NULL));
	switch (dificultad) {
	case 1: {
		int randJewel = rand() % 4 + 1;
		return randJewel;
	}
	case 2: {
		int randJewel = rand() % 6 + 1;
		return randJewel;
	}
	case 3: {
		int randJewel = rand() % 8 + 1;
		return randJewel;
	}
	}
	return -1;
}

void generacionInicialRandomJewels(float *tablero, int dificultad, int anchura, int altura) {
	srand(time(NULL));
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
void bombaFila(float* tablero, int anchura, int altura, int dificultad, int fila) {

	for (int iFila = 0; (iFila + fila) < altura; iFila++)
	{
		for (int iColm = 0; iColm < anchura; iColm++)
		{
			if ((iFila + fila + 1) < altura)
			{
				tablero[(iFila + fila)*anchura + iColm] = tablero[(iFila + fila + 1)*altura + iColm];
			}
			else {
				tablero[(iFila + fila)*anchura + iColm] = generarJewel(dificultad);
			}
		}
	}
}

void bombaColumna(float* tablero, int anchura, int altura, int dificultad, int columna) {

	for (int iFila = 0; iFila < altura; iFila++)
	{
		for (int iColm = 0; (iColm + columna) < anchura; iColm++)
		{
			if ((iColm + columna + 1) == anchura)
			{
				tablero[(iFila*anchura) + (iColm + columna)] = generarJewel(dificultad);
			}
			else {
				tablero[(iFila*anchura) + (iColm + columna)] = tablero[(iFila*altura) + (iColm + columna + 1)];
			}
		}
	}
}
void bombaRotarCPU(float* tablero, int anchura, int altura, int fila, int columna)
{
	float aux[9];
	int index = 0;
	for (int iColm = columna - 1; iColm <= columna + 1; iColm++)
	{
		for (int iFila = fila + 1; iFila >= fila - 1; iFila--)
		{
			aux[index] = tablero[iFila*anchura + iColm];
			index++;
		}
	}
	index = 0;
	for (int iFila = 0; iFila < 3; iFila++)
	{
		for (int iColumna = 0; iColumna < 3; iColumna++)
		{
			tablero[(iFila + fila - 1)*anchura + (columna - 1) + iColumna] = aux[index];
			index++;
		}
	}
}
int main() {
	//Matriz de tamaño variable de floats, un array de Altura*Anchura
	int anchura = 2;
	int altura = 2;
	int dificultad = 1;
	bool automatico = true;
	int TILE_WIDTH = 16;
	int size;

	char ficheroGuardado[9] = "save.txt";

	float *tablero;
	float* tablero_d;
	bool jugando = true;

	int eleccion = 2;
	bool encontrado = false;
	std::cout << "Desea cargar una partida guardada? 1.-SI   2.-NO\n";
	std::cin >> eleccion;
	if (eleccion == 1)
	{
		encontrado = precargar(anchura, altura, dificultad, ficheroGuardado);
		std::cout << "Cargando Tablero de " << anchura << "x" << altura << " con dificultad: " << dificultad;
		std::cout << std::endl;
	}
	if (!encontrado || (eleccion == 2))
	{
		std::cout << "Anchura del tablero: ";
		std::cin >> anchura;

		std::cout << "Altura del tablero: ";
		std::cin >> altura;

		std::cout << "Elija dificultad: \n1.-Facil \n2.-Media \n3.-Dificil\n";
		std::cin >> dificultad;
	}
	int seleccion;
	std::cout << "Automatico?   1.-SI   2.-NO\n";
	std::cin >> seleccion;

	switch (seleccion) {
	case 1: automatico = true; break;
	case 2: automatico = false; break;
	default: printf("Valor no valido.\n"); return -1;
	}
	size = anchura*altura;
	tablero = (float*)malloc(size * sizeof(float));
	cudaMalloc((void**)&tablero_d, size);
	//Se inicializa la matriz
	if (encontrado)
	{
		cargar(anchura, altura, tablero, ficheroGuardado);
		std::cout << "Se ha cargado el Tablero: \n";
	}
	else {
		generacionInicialRandomJewels(tablero, dificultad, anchura, altura);
		std::cout << "Se crea un tablero nuevo: \n";
	}
	//Bucle principal del juego
	while (jugando) {

		printTablero(tablero, anchura, altura);

		int jewel1_x = 0;
		int jewel1_y = 0;
		int accion = 0;

		std::cout << "Acción a realizar:\n";
		std::cout << "(1) Intercambiar Jewels\n";
		std::cout << "(2) Usar una Bomba\n";
		std::cout << "(3) Guardar partida\n";
		std::cout << "(4) Exit\n";
		std::cout << "Elija accion: ";

		std::cin >> accion;


		switch (accion) {
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

				if (seleccion == 1)
					analisisTableroAutomatico(dificultad, tablero, anchura, altura);
				else
					intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion, anchura, altura, seleccion, dificultad);
			}

			break;
		}
		case 2: {
			// Bomba
			int bomba = 0;
			int fila = 0, columna = 0;
			std::cout << "Elija una bomba:";

			/* Bombas por tipo de dificultad */
			switch (dificultad) {
			case 1: {
				std::cout << "(1) Bomba de fila ";
				std::cout << "\nEleccion: ";
				std::cin >> bomba;

				if (bomba != 1)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				std::cout << "X: ";
				std::cin >> fila;
				bombaFila(tablero, anchura, altura, dificultad, fila);
				break;
			}
			case 2: {
				std::cout << "(1) Bomba de fila";
				std::cout << "(2) Bomba de columna";
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
					std::cout << "X: ";
					std::cin >> fila;
					bombaFila(tablero, anchura, altura, dificultad, fila);
					break;
				}
				case 2:
				{
					std::cout << "Y: ";
					std::cin >> columna;
					bombaColumna(tablero, anchura, altura, dificultad, columna);
					break;
				}
				}
				break;
			}
			case 3: {
				std::cout << "(1) Bomba de fila";
				std::cout << "(2) Bomba de columna";
				std::cout << "(3) Bomba de rotacion 3x3 (la jewel elegida es el centro)";
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
					std::cout << "X: ";
					std::cin >> fila;
					bombaFila(tablero, anchura, altura, dificultad, fila);
					break;
				}
				case 2:
				{
					std::cout << "Y: ";
					std::cin >> columna;
					bombaColumna(tablero, anchura, altura, dificultad, columna);
					break;
				}
				case 3:
				{
					std::cout << "X: ";
					std::cin >> fila;
					std::cout << "Y: ";
					std::cin >> columna;
					if ((fila - 1) < 0 || (fila + 1) >= altura || (columna - 1) < 0 || (columna + 1) >= anchura)
					{
						std::cout << "Rotacion no valida" << std::endl;
					}
					else
					{
						bombaRotarCPU(tablero, anchura, altura, fila, columna);
					}
					break;
				}
				}
				break;
			}
			}
			break;
		}
		case 3: {
			guardado(tablero, anchura, altura, dificultad, ficheroGuardado);
			std::cout << "Guardado correcto.\n";
			break;
		}
		case 4:
		{
			free(tablero);
			cudaFree(tablero_d);
			return 0;
		}
		}

	}

	free(tablero);
	cudaFree(tablero_d);
	return 0;
}