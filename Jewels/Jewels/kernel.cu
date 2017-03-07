#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>
#include <curand.h>
#include <curand_kernel.h>
#include <ctime>

#include <fstream>

//Funci�n que llamara a la de CUDA para actualizar la matrz
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
			printf("%d ", (int)tablero[j+i*anchura]);
		}
	}
	printf("\n");
}

//TODO: revisar
void eliminarJewelsCPU(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura) {
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;
	//printf("\nJewels a eliminar horizontal: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas_d[0], jewels_eliminadas_d[1] / anchura, jewels_eliminadas_d[2], jewels_eliminadas_d[3] / anchura, jewels_eliminadas_d[4], jewels_eliminadas_d[5] / anchura);
	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			for (int i = 0; i < max; i++) {
				if ((x == jewels_eliminadas[i]) && (y * anchura) > (jewels_eliminadas[i + 1])) {
					tablero[x + (y - 1)*(anchura)] = tablero[x + y*anchura];
				}

				if (y == altura) {
					//Generar jewel random

					switch (dificultad) {
					case 1: {
						int randJewel = rand() % 4 + 1;
						tablero[x+y*anchura] = randJewel;
						break;
					}
					case 2: {
						int randJewel = rand() % 6 + 1;
						tablero[x+y*anchura] = randJewel;
						break;
					}
					case 3: {
						int randJewel = rand() % 8 + 1;
						tablero[x + y*anchura] = randJewel;
						break;
					}
					}
				}
				i++;
			}
		}
	}
}

//TODO: Usar tx y ty como doble for anidado
__global__ void eliminarJewelsKernel(float* tablero_d, float* jewels_eliminadas_d,int dificultad, int anchura, int altura) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	int max = 0;

	if (altura >= anchura) max = altura;
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
	}
}

//Elimina las jewels recibidas, bajas las filas para rellenas, y genera arriba del todo jewels nuevas. TODO
void eliminarJewels(float* tablero, float* jewels_eliminadas,int dificultad, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, max * sizeof(float));
	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, max * sizeof(float), cudaMemcpyHostToDevice);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del calculo, misma funcion de analisis en manual y automatico
	eliminarJewelsKernel <<<dimGrid, dimBlock >>>(tablero_d, jewels_eliminadas_d, dificultad, anchura, altura);

	//Transfiere las jewels a eliminar de la GPU al host
	cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
}

/*__global__ void analisisTableroKernel(float *tablero_d, float *jewels_eliminadas_d, int dificultad, int anchura, int altura) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;

	//printf("\ntx:%i ty:%i\n",tx,ty);

	if (tx > 1 && tx < anchura - 1) {
		if (tablero_d[tx + anchura*ty] == tablero_d[tx + 1 + anchura*ty] && tablero_d[tx + anchura*ty] == tablero_d[tx - 1 + anchura*ty]){
			jewels_eliminadas_d[0] = tx - 1;
			jewels_eliminadas_d[1] = anchura*ty;
			jewels_eliminadas_d[2] = tx;
			jewels_eliminadas_d[3] = anchura*ty;
			jewels_eliminadas_d[4] = tx + 1;
			jewels_eliminadas_d[5] = anchura*ty;
			//printf("\nJewels a eliminar horizontal: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas_d[0], jewels_eliminadas_d[1]/anchura, jewels_eliminadas_d[2], jewels_eliminadas_d[3] / anchura, jewels_eliminadas_d[4], jewels_eliminadas_d[5] / anchura);
		}
	}

	if (ty > 1 && ty < altura - 1) {
		if (tablero_d[tx + anchura*ty] == tablero_d[tx + anchura*(ty + 1)] && tablero_d[tx + anchura*ty] == tablero_d[tx + anchura*(ty - 1)]) {
			jewels_eliminadas_d[0] = tx;
			jewels_eliminadas_d[1] = anchura*(ty - 1);
			jewels_eliminadas_d[2] = tx;
			jewels_eliminadas_d[3] = anchura*ty;
			jewels_eliminadas_d[4] = tx;
			jewels_eliminadas_d[5] = anchura*(ty + 1);
			//printf("\nty: %i\n",ty);
			//printf("\nJewels a eliminar vertical: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas_d[0], (jewels_eliminadas_d[1]/ anchura), jewels_eliminadas_d[2], jewels_eliminadas_d[3] / anchura, jewels_eliminadas_d[4], (jewels_eliminadas_d[5] / anchura));
		}
	}
}*/

//Funcion CPU. FUNCIONA HORIZONTAL, FALTA VERTICAL CORREGIR
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

	//Tiene posibles eliminables por la derecha o izquierda
	// (((x-1+y*anchura>=0)&&tablero[x - 1 + y*anchura] == tablero[x + y*anchura]) || ((x+1+y*anchura<=size)&&tablero[x + 1 + y*anchura] == tablero[x + y*anchura])) {
		int jewels_posibles_izq = 0;
		int jewels_posibles_der = 0;
		printf("\nHORIZONTAL\n");
		//Si tiene por la izquierda
		if ((x - 1 + y*anchura >= 0) && tablero[x - 1 + y*anchura] == tablero[x + y*anchura]) {
			int i = 1;
			while ((x - i + y*anchura >= 0) && tablero[x - i + y*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_izq++;
				i++;
			}
		}

		//Si tiene por la derecha
		if ((x + 1 + y*anchura <= size) && tablero[x + 1 + y*anchura] == tablero[x + y*anchura]) {
			int i = 1;
			while ((x + i+ y*anchura <= size) && tablero[x + i + y*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_der++;
				i++;
			}
		}

		//Se pueden eliminar horizontalmente
		if (1 + jewels_posibles_izq + jewels_posibles_der >= 3) {
			jewels_eliminadas[0] = x;
			jewels_eliminadas[1] = y;

			int salto = 2;

			for (int j = 1; j <= (jewels_posibles_izq);j++) {
				jewels_eliminadas[salto]=x-j;
				jewels_eliminadas[salto + 1]=y;
				salto += 2;
			}

			salto = 2;
			for (int k = 1; k <= jewels_posibles_der; k++) {
				jewels_eliminadas[salto + 1 + jewels_posibles_izq] = x + k;
				jewels_eliminadas[salto + 1 + jewels_posibles_izq+1] = y;
				salto += 2;
			}
		} else {	//Analizamos la vertical
			int jewels_posibles_arrib = 0;
			int jewels_posibles_abaj = 0;

			printf("\nVERTICAL\n");
			//Si tiene por abajo
			if ((x + (y - 1)*anchura >= 0) && tablero[x + (y - 1)*anchura] == tablero[x + y*anchura]) {
				printf("\nABAJO\n");
				int i = 1;
				while ((x + (y - i)*anchura >= 0) && tablero[x + (y - i)*anchura] == tablero[x + y*anchura]) {
					jewels_posibles_abaj++;
					printf("\nTIENE ABAJO\n");
					i++;
				}
			}

			//Si tiene por arriba
			if ((x + 1 + y*anchura <= size) && tablero[x + (y + 1)*anchura] == tablero[x + y*anchura]) {
				printf("\nARRIBA\n");
				int i = 1;
				while ((x + (y + i)*anchura <= size) && tablero[x + (y + i)*anchura] == tablero[x + y*anchura]) {
					jewels_posibles_arrib++;
					printf("\nTIENE ARRIBA\n");
					i++;
				}
			}

			//Se pueden eliminar
			if (1 + jewels_posibles_abaj + jewels_posibles_arrib >= 3) {
				printf("\nSE PUEDE\n");

				jewels_eliminadas[0] = x;
				jewels_eliminadas[1] = y;

				int salto = 2;
				for (int j = 1; j <= (jewels_posibles_abaj); j++) {
					jewels_eliminadas[salto] = x;
					jewels_eliminadas[salto + 1] = y - j;
					salto += 2;
				}

				salto = 2;
				for (int k = 1; k <= jewels_posibles_arrib; k++) {
					jewels_eliminadas[salto + jewels_posibles_abaj] = x;
					jewels_eliminadas[salto + 1 + jewels_posibles_abaj + 1] = y + k;
					salto += 2;
				}
			}
		}
		
	//("\nJewels a eliminar horizontal: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas_d[0], jewels_eliminadas_d[1] / anchura, jewels_eliminadas_d[2], jewels_eliminadas_3] / anchura, jewels_eliminadas[4], jewels_eliminadas[5] / anchura);
	for (int q = 0; q < 2*max; q++) {
		if (q % 2 != 0) {
			printf(" y:%f\n",jewels_eliminadas[q]);
		}
		else {
			printf("| x:%f\n", jewels_eliminadas[q]);
		}
	}
	if(jewels_eliminadas[0]!=-1)
		eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura);
}

//CUDA CPU Function
/*void analisisTableroManual(int dificultad, float* tablero, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan 3 jewels, 2 coordenadas por jewel = 6 posiciones en el array
	float* jewels_eliminadas = (float*)malloc(max * sizeof(float));

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, max * sizeof(float));
	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, max * sizeof(float), cudaMemcpyHostToDevice);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del calculo, misma funcion de analisis en manual y automatico
	analisisTableroKernel <<<dimGrid, dimBlock>>>(tablero_d, jewels_eliminadas_d, dificultad, anchura, altura);
	printf("\nSali!\n");

	//Transfiere las jewels a eliminar de la GPU al host
	cudaMemcpy(jewels_eliminadas, jewels_eliminadas_d, max*sizeof(float), cudaMemcpyDeviceToHost);

	printTablero(tablero, anchura, altura);
	printf("Pulse una tecla para continuar...");
	int relleno = 0;
	std::cin >> relleno;
	if (jewels_eliminadas[0] == -1 && jewels_eliminadas[1]==-1) {
		//Se eliminan las jewels seleccionadas, se bajan las superiores y se generan nuevas
		cudaFree(tablero_d);
		cudaFree(jewels_eliminadas_d);

		//printf("\nJewels a eliminar: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas[0], jewels_eliminadas[1]/anchura, jewels_eliminadas[2], jewels_eliminadas[3]/anchura, jewels_eliminadas[4], jewels_eliminadas[5]/anchura);
		analisisTableroManual(dificultad, tablero, anchura, altura);
	}
	else {
		cudaFree(tablero_d);
		cudaFree(jewels_eliminadas_d);

		//printf("\nJewels a eliminar: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas[0], jewels_eliminadas[1]/anchura, jewels_eliminadas[2], jewels_eliminadas[3]/anchura, jewels_eliminadas[4], jewels_eliminadas[5]/anchura);
		eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura);
		printTablero(tablero, anchura, altura);
	}
}*/

//CUDA CPU Function. Analiza la mejor opcion y la ejecuta
void analisisTableroAutomatico(int dificultad, float* tablero, int anchura, int altura) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan 3 jewels, 2 coordenadas por jewel = 6 posiciones en el array
	float* jewels_eliminadas = (float*)malloc(max * sizeof(float));

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU
	cudaMalloc((void**)&jewels_eliminadas_d, max * sizeof(float));
	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, max * sizeof(float), cudaMemcpyHostToDevice);

	//Configuracion de ejecucion, 1 hilo por bloque, tantos bloques como celdas
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del calculo, misma funcion de analisis en manual y automatico
	//analisisTableroKernel << <dimGrid, dimBlock >> >(tablero_d, jewels_eliminadas_d, dificultad, anchura, altura);
	//printf("\nSali!\n");

	//Transfiere las jewels a eliminar de la GPU al host
	cudaMemcpy(jewels_eliminadas, jewels_eliminadas_d, max * sizeof(float), cudaMemcpyDeviceToHost);

	if (jewels_eliminadas[0] == -1 && jewels_eliminadas[1] == -1) {
		//Se eliminan las jewels seleccionadas, se bajan las superiores y se generan nuevas
		cudaFree(tablero_d);
		cudaFree(jewels_eliminadas_d);

		//printf("\nJewels a eliminar: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas[0], jewels_eliminadas[1]/anchura, jewels_eliminadas[2], jewels_eliminadas[3]/anchura, jewels_eliminadas[4], jewels_eliminadas[5]/anchura);
		analisisTableroAutomatico(dificultad, tablero, anchura, altura);
	}
	else {
		cudaFree(tablero_d);
		cudaFree(jewels_eliminadas_d);

		//printf("\nJewels a eliminar: x:%f y:%f | x:%f y:%f | x:%f y:%f", jewels_eliminadas[0], jewels_eliminadas[1]/anchura, jewels_eliminadas[2], jewels_eliminadas[3]/anchura, jewels_eliminadas[4], jewels_eliminadas[5]/anchura);
		eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura);
		printTablero(tablero, anchura, altura);
	}
}

void intercambiarPosiciones(float* tablero, int jewel1_x, int jewel1_y, int direccion, int anchura, int altura, int seleccion,int dificultad) {
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

	aux1 = tablero[jewel2_x+jewel2_y*anchura];

	tablero[jewel2_x+jewel2_y*anchura] = tablero[jewel1_x+jewel1_y*anchura];
	tablero[jewel1_x+jewel1_y*anchura] = aux1;

	if (seleccion == 2)
		analisisTableroManual(dificultad, tablero, anchura, altura, jewel2_x, jewel2_y);
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
	dificultad = (int)tam[2] -48;

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
		tablero[i] = array[i + 3];
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

int main() {
	//Matriz de tama�o variable de floats, un array de Altura*Anchura
	int anchura = 2;
	int altura = 2;
	int dificultad = 1;
	bool automatico = true;
	int TILE_WIDTH = 16;
	char ficheroGuardado[9] = "save.txt";

	float *tablero;
	bool jugando = true;

	int eleccion;
	bool encontrado = false;
	std::cout << "Desea cargar una partida guardada? 1.-SI   2.-NO\n";
	std::cin >> eleccion;
	if (eleccion == 1)
	{
		encontrado = precargar(anchura, altura, dificultad, ficheroGuardado);
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
	
	tablero = (float*)malloc(altura * anchura * sizeof(float));

	//Se inicializa la matriz
	if (encontrado)
	{
		cargar(anchura, altura, tablero, ficheroGuardado);
	}
	generacionInicialRandomJewels(tablero, dificultad, anchura, altura);
	
	//Bucle principal del juego
	while (jugando) {

		printTablero(tablero, anchura, altura);
		
		int jewel1_x = 0;
		int jewel1_y = 0;
		int accion = 0;

		std::cout << "Acci�n a realizar:\n";
		std::cout << "(1) Intercambiar Jewels\n";
		std::cout << "(2) Usar una Bomba\n";
		std::cout << "(3) Guardar partida\n";
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

					intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion, anchura, altura, seleccion, dificultad);

					if (seleccion == 1)
						analisisTableroAutomatico(dificultad, tablero, anchura, altura);
				}

			break;
		}
		case 2: {
			// Bomba
			int bomba = 0;

			std::cout << "Elija una bomba:";

			switch (dificultad) {
			case 1: {
				std::cout << "(1) Bomba de fila";
				break;
			}
			case 2: {
				std::cout << "(1) Bomba de fila";
				std::cout << "(2) Bomba de columna";
				break;
			}
			case 3: {
				std::cout << "(1) Bomba de fila";
				std::cout << "(2) Bomba de columna";
				std::cout << "(3) Bomba de rotacion 3x3 (la jewel elegida es el centro)";
				break;
			}
			}

			std::cin >> bomba;

			switch (dificultad)
			{
			case 1:
			{
				if (bomba != 1)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				break;
			}
			case 2:
			{
				if (bomba < 1 && bomba > 2)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				break;
			}
			case 3:
			{
				if (bomba < 1 && bomba > 3)
				{
					printf("Bomba erronea.\n");
					continue;
				}
				break;
			}
			}

			//LLAMADA A LA FUNCION DE EJECUTAR BOMBA//


			break;
		}
		case 3: {
			guardado(tablero, anchura, altura, dificultad, ficheroGuardado);
			std::cout << "Guardado correcto.\n";
			break;
		}
		}
			
	}
	return 0;
}