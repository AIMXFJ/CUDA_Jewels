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
void printTablero(float* tablero, int anchura, int altura) {
	for (int i = altura - 1; i >= 0; i--) {
		printf("\n");
		for (int j = 0; j < anchura; j++) {
			printf("%d ", (int)tablero[j + i*anchura]);
		}
	}
	printf("\n");
}

/*Recibe las coordenadas de las jewels a eliminar y mueve las filas que tiene que bajar a partir de ellas, emplea
una copia del tablero para evitar race conditions*/
__global__ void eliminarJewelsKernel(float* tablero_d, float* tablero_aux_d, float* jewels_eliminadas_d, int dificultad, int anchura, int altura, int final, curandState* globalState) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;

	if (jewels_eliminadas_d[0] != jewels_eliminadas_d[2] && tx >= jewels_eliminadas_d[0] && tx <= jewels_eliminadas_d[final - 2] && ty >= jewels_eliminadas_d[1]) {
		if (ty + 1 < altura) {

			float value = tablero_aux_d[tx + (ty + 1)*anchura];

			tablero_d[tx + (ty)*(anchura)] = value;
		}
		else {
			tablero_d[tx + ty*anchura] = generarJewelCUDA(globalState, tx + ty*anchura, dificultad);
		}
	}
	else {

		if (ty < altura && tx == jewels_eliminadas_d[0] && ty > jewels_eliminadas_d[1]) {

			float value = tablero_aux_d[tx + (ty)*anchura];

			tablero_d[tx + (ty - final / 2)*(anchura)] = value;

		}

		if (ty >= altura - final / 2 && ty < altura && tx == jewels_eliminadas_d[0]) {

			tablero_d[tx + (ty)*anchura] = generarJewelCUDA(globalState, tx + ty*anchura, dificultad);

		}
	}
}

/*Funcion que prepara y llama el kernel con su mismo nombre, genera todos los datos necesarios*/
void eliminarJewels(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura, curandState* globalState) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	float *tablero_aux_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	//Para saber que medida es la m�s grande, ya que no se pueden eliminar m�s jewels seguidas que esa medida
	if (altura >= anchura) max = altura;
	else max = anchura;

	//Tablero a GPU y la copia del tablero
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);
	cudaMalloc((void**)&tablero_aux_d, size);
	cudaMemcpy(tablero_aux_d, tablero, size, cudaMemcpyHostToDevice);

	//Jewels a eliminar a GPU. 2*max ya que cada posicion son dos coordenadas, x e y
	cudaMalloc((void**)&jewels_eliminadas_d, 2 * max * sizeof(float));

	cudaMemcpy(jewels_eliminadas_d, jewels_eliminadas, 2 * max * sizeof(float), cudaMemcpyHostToDevice);

	int final = 0;
	bool modif = false;

	//Calcula cual es el ultimo valor escrito de las jewels a eliminar, ya que puede haber posiciones no escritas
	for (int i = 0; i < max * 2; i++) {
		if (jewels_eliminadas[i] < 0) {
			final = i;
			modif = true;
			break;
		}
	}

	//En caso de que este completamente escrito
	if (!modif) final = max * 2;

	//Configuracion de ejecucion
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	eliminarJewelsKernel << <dimGrid, dimBlock >> > (tablero_d, tablero_aux_d, jewels_eliminadas_d, dificultad, anchura, altura, final, globalState);

	//Se recupera el tablero actualizado

	cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

	//Libera memoria
	cudaFree(tablero_d);
	cudaFree(jewels_eliminadas_d);
	cudaFree(tablero_aux_d);
}

/*Escribe en un tablero auxiliar la cantidad de jewels que se eliminarian moviendo una jewel (x,y) hacia la derecha
paralelizable ya que todos los hilos (cada hilo 1 jewel) tienen que expandirse hacia la derecha para ver hasta donde llegarian a eliminar*/
__global__ void analisisTableroAutomaticoKernel(float *tablero_d, float *aux_d, int dificultad, int anchura, int altura) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;

	int jewels_posibles_der = 0;

	//Si tiene por la derecha
	if ((tx + 2) < anchura) {
		if (((tx + 2) + ty*anchura <= altura*anchura) && tablero_d[tx + 2 + ty*anchura] == tablero_d[tx + ty*anchura]) {
			int i = 2;
			//Se expande
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
	//printf("%i-%f ", tx + ty*anchura, aux_d[tx + ty*anchura]);
}

//Analiza el movimiento manual, usando las coordenadas de la nueva posicion de la jewel seleccionada
void analisisTableroManual(int dificultad, float* tablero, int anchura, int altura, int x, int y, curandState* globalState) {
	int max = 0;
	int size = anchura*altura;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan MAX jewels como mucho, se guardan sus x e y
	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));

	//Se inicializa a -1 �ra saber hasta que punto se escribe
	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	int jewels_posibles_izq = 0;
	int jewels_posibles_der = 0;

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

	//Se pueden eliminar horizontalmente, las coloca en orden para facilitar su eliminacion
	if (1 + jewels_posibles_izq + jewels_posibles_der >= 3) {
		int salto = 0;

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

		//Si tiene por abajo
		if ((x + (y - 1)*anchura >= 0) && tablero[x + (y - 1)*anchura] == tablero[x + y*anchura]) {
			int i = 1;
			while ((x + (y - i)*anchura >= 0) && tablero[x + (y - i)*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_abaj++;
				i++;
			}
		}

		//Si tiene por arriba
		if ((x + 1 + y*anchura <= size) && tablero[x + (y + 1)*anchura] == tablero[x + y*anchura]) {
			int i = 1;
			while ((x + (y + i)*anchura <= size) && tablero[x + (y + i)*anchura] == tablero[x + y*anchura]) {
				jewels_posibles_arrib++;
				i++;
			}
		}

		//Se pueden eliminar
		if (1 + jewels_posibles_abaj + jewels_posibles_arrib >= 3) {

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

	//Las elimina
	eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura, globalState);
	free(jewels_eliminadas);
}

//Intercambia la jewel seleccionadas con la jewel en la direcci�n indicada
void intercambiarPosiciones(float* tablero, int jewel1_x, int jewel1_y, int direccion, int anchura, int altura, int seleccion, int dificultad, curandState* globalState) {
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

	//Analiza el movimiento para ver si se pueden eliminar jewels
	analisisTableroManual(dificultad, tablero, anchura, altura, jewel2_x, jewel2_y, globalState);
}

//Analiza la mejor opcion y la ejecuta en funcion de lo que devuelve el kernel
void analisisTableroAutomatico(int dificultad, float* tablero, int anchura, int altura, curandState* globalState) {
	float *tablero_d;
	float *aux_d;
	float *aux;
	//Tama�o del tablero para asignar memoria
	int size = anchura * altura * sizeof(float);
	int tam = anchura * altura;
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan max jewels, 2 coordenadas por jewel = 2 * max posiciones

	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));
	aux = (float*)malloc(size);

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	//Solo se cuenta la jewel que se escoge, sigue siendo menor que 3
	for (int p = 0; p < tam; p++) {
		aux[p] = 1;
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);

	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);
	//Auxiliar de conteo a GPU

	cudaMalloc((void**)&aux_d, size);

	cudaMemcpy(aux_d, aux, size, cudaMemcpyHostToDevice);

	//Configuracion de ejecucion
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);

	//Inicio del kernel

	analisisTableroAutomaticoKernel << <dimGrid, dimBlock >> > (tablero_d, aux_d, dificultad, anchura, altura);

	//Transfiere el resultado de la GPU al host
	cudaMemcpy(aux, aux_d, size, cudaMemcpyDeviceToHost);

	int x_mejor = 0;
	int y_mejor = 0;
	int valor_mejor = 0;

	//Se busca el movimiento con el mayor numero de jewels eliminadas
	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			if (aux[x + y*anchura] > valor_mejor) {
				valor_mejor = aux[x + y*anchura];
				x_mejor = x;
				y_mejor = y;
			}
		}
	}

	//Si se pueden eliminar se ejecuta el movimiento, con lo que ello conlleva
	if (valor_mejor >= 3) {
		intercambiarPosiciones(tablero, x_mejor, y_mejor, 4, anchura, altura, 1, dificultad, globalState);
	}
	free(aux);
	free(jewels_eliminadas);
	cudaFree(tablero_d);
	cudaFree(aux_d);
}

bool precargar(int& anchura, int& altura, int& dificultad, char* fichero)
{
	std::ifstream fAnchura("anchura.txt");
	if (!fAnchura.is_open())
	{
		std::cout << "ERROR: no existe un archivo guardado." << std::endl;
		return false;
	}
	fAnchura >> anchura;
	fAnchura.close();

	std::ifstream fAltura("altura.txt");
	
	if (!fAltura.is_open())
	{
		std::cout << "ERROR: no existe un archivo guardado." << std::endl;
		return false;
	}
	fAltura >> altura;
	fAltura.close();
	std::ifstream fDificultad("dificultad.txt");

	if (!fDificultad.is_open())
	{
		std::cout << "ERROR: no existe un archivo guardado." << std::endl;
		return false;
	}
	fDificultad >> dificultad;
	fDificultad.close();
	std::ifstream fCarga(fichero);
	if (!fCarga.is_open())
	{
		std::cout << "ERROR: no existe un archivo guardado." << std::endl;
		return false;
	}
	fCarga.close();
	return true;
}

void cargar(int anchura, int altura, float*  tablero, char* fichero)
{
	int aux;
	char* array = (char*)malloc(anchura*altura + 1);
	std::ifstream fCarga(fichero);
	fCarga.getline(array, anchura*altura + 1);

	for (int i = 0; i < anchura*altura; i++)
	{
		aux = (array[i] - 48);
		tablero[i] = (float)aux;
	}
	free(array);
	fCarga.close();

}

void guardado(float* tablero, int anchura, int altura, int dificultad, char* fichero)
{
	//Sistema de guardado
	
	std::ofstream ficheroAnchura;
	ficheroAnchura.open("Anchura.txt");
	ficheroAnchura.clear();
	ficheroAnchura << anchura;
	ficheroAnchura.close();
	std::ofstream ficheroAltura;
	ficheroAltura.open("Altura.txt");
	ficheroAltura.clear();
	ficheroAltura << altura;
	ficheroAltura.close();
	std::ofstream ficheroDificultad;
	ficheroDificultad.open("Dificultad.txt");
	ficheroDificultad.clear();
	ficheroDificultad << dificultad;
	ficheroDificultad.close();

	std::ofstream ficheroGuardado;
	ficheroGuardado.open(fichero);
	ficheroGuardado.clear();

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
			if ((columna - tColumna - 1) < 0)
			{
				tablero[(tFila*anchura) + (columna - tColumna)] = generarJewelCUDA(globalState, (tFila * 3 + tColumna), dificultad);
			}
			else {
				tablero[(tFila*anchura) + (columna - tColumna)] = tablero[(tFila*anchura) + (columna - tColumna - 1)];
			}
		}
	}
}

__global__ void bombaRotarGPU(float* tablero, int anchura, int altura, int fila, int columna)
{
	int tFila = threadIdx.y;
	int tColumna = threadIdx.x;

	if (tFila < 3)
	{
		if (tColumna < 3)
		{
			tablero[(fila + 1 - tColumna)*anchura + (columna - 1 + tFila)] = tablero[((fila + 1) - tFila)*anchura + ((columna + 1) - tColumna)];
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
				//printf(" %i-%i ", tFila, tColumna);
				bombaRotarGPU << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, tFila, tColumna);
				//__syncthreads();
			}
		}
	}
}
int main(int argc, char** argv) {
	//Matriz de tama�o variable de floats, un array de Altura*Anchura
	int anchura;
	int altura;
	int dificultad;
	char modo;
	int size;
	char ficheroGuardado[9] = "save.txt";
	int seleccion;

	float* tablero;
	float* tablero_d;

	curandState* devStates;

	bool jugando = true;
	/* Valores por argumento*/
	if (argc == 1)
	{
		std::cout << "Anchura del tablero: ";
		std::cin >> anchura;

		std::cout << "Altura del tablero: ";
		std::cin >> altura;

		std::cout << "Elija dificultad: \n1.-Facil \n2.-Media \n3.-Dificil\n";
		std::cin >> dificultad;

		std::cout << "Automatico?   1.-SI   2.-NO\n";
		std::cin >> seleccion;
	}
	else
	{
		modo = argv[1][1];
		dificultad = atoi(argv[2]);
		anchura = atoi(argv[3]);
		altura = atoi(argv[4]);

		switch (modo) {
		case 'a': {seleccion = 1; break; }
		case 'm': {seleccion = 2; break; }
		default: printf("Valor no valido.\n"); return -1;
		}
	}

	size = anchura*altura;

	/* Inicializacion random en CUDA */
	cudaMalloc(&devStates, size * sizeof(curandState));

	/* Creacion de las Seeds */
	setup_kernel << < 1, size >> > (devStates, unsigned(time(NULL)));

	/* Reservar memoria para tablero y tablero_d */
	tablero = (float*)malloc(size * sizeof(float));
	cudaMalloc((void**)&tablero_d, size * sizeof(float));

	/* Se inicializa la matriz */
	dim3 dimBlock(anchura, altura);
	dim3 dimGrid(1, 1);
	generacionInicialRandomJewels << <dimGrid, dimBlock >> >(tablero_d, dificultad, anchura, altura, devStates);
	cudaMemcpy(tablero, tablero_d, size * sizeof(float), cudaMemcpyDeviceToHost);

	//Bucle principal del juego
	while (jugando) {
		
		printTablero(tablero, anchura, altura);

		int jewel1_x = 0;
		int jewel1_y = 0;
		int accion = 0;

		std::cout << "Acci�n a realizar:\n";
		std::cout << "(1) Intercambiar Jewels\n";
		std::cout << "(2) Guardar partida\n";
		std::cout << "(3) Cargar partida\n";
		std::cout << "(9) Usar una Bomba\n";
		std::cout << "(0) Exit\n";
		std::cout << "Elija accion: ";

		std::cin >> accion;

		switch (accion) {
			/* EXIT */
		case 0: {
			free(tablero);
			cudaFree(tablero_d);
			cudaFree(devStates);
			return 0;
		}
				/* Intercambio de jewel */
		case 1: {
			if (seleccion == 2)
			{
				std::cout << "Posicion de la primera jewel a intercambiar (empiezan en 0)\n";
				std::cout << "Columna: ";
				std::cin >> jewel1_x;
				std::cout << "Fila: ";
				std::cin >> jewel1_y;

				if (!((jewel1_x < anchura) && (jewel1_x >= 0) && (jewel1_y < altura) && (jewel1_y >= 0))) {
					printf("Posicion erronea.\n");
					continue;
				}

				int direccion = 0;
				std::cout << "Direccion a seguir para intercambio de posiciones: \n 1.-Arriba\n 2.-Abajo\n 3.-Izquierda\n 4.-Derecha\n";
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
				}
				/* Intercambiar posiciones */
				intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion, anchura, altura, seleccion, dificultad, devStates);

			}
			else if (seleccion == 1)
			{
				/* Analisis automatico */
				analisisTableroAutomatico(dificultad, tablero, anchura, altura, devStates);
			}
			break;
		}
				/* Guardar Partida */
		case 2: {

			guardado(tablero, anchura, altura, dificultad, ficheroGuardado);
			std::cout << "Guardado correcto.\n";
			break;
		}
				/* Cargar Partida */
		case 3: {

			/* Precarga de tablero */
			int encontrado = precargar(anchura, altura, dificultad, ficheroGuardado);
			printf("%i\n", anchura);
			printf("%i\n", altura);
			size = anchura*altura;
			if (encontrado)
			{
				free(tablero);
				cudaFree(tablero_d);
				tablero = (float*)malloc(size * sizeof(float));
				cudaMalloc((void**)&tablero_d, size * sizeof(float));
				/* Cargar tablero */
				cargar(anchura, altura, tablero, ficheroGuardado);
				std::cout << "Automatico?   1.-SI   2.-NO\n";
				std::cin >> seleccion;
				std::cout << "Se ha cargado el Tablero: \n";
			}
			else {
				std::cout << "No existe ninguna partida guardada.\n";
			}
			break;

		}
				/* Bombas */
		case 9: {

			int bomba = 0;
			int fila = 0; int columna = 0;
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
				std::cout << "Fila: ";
				std::cin >> fila;
				dim3 dimBlock(anchura, altura);
				dim3 dimGrid(1, 1);
				cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
				bombaFila << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
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
					std::cout << "Fila: ";
					std::cin >> fila;
					dim3 dimBlock(anchura, altura);
					dim3 dimGrid(1, 1);
					cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
					bombaFila << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
					break;
				}
				case 2:
				{
					std::cout << "Columna: ";
					std::cin >> columna;
					dim3 dimBlock(anchura, altura);
					dim3 dimGrid(1, 1);
					cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
					bombaColumna << <dimGrid, dimBlock >> >(tablero_d, anchura, altura, dificultad, columna, devStates);
					break;
				}
				}
				break;
			}
			case 3: {
				std::cout << "(1) Bomba de fila";
				std::cout << "(2) Bomba de columna";
				std::cout << "(3) Bomba de rotacion 3x3";
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
					dim3 dimBlock(anchura, altura);
					dim3 dimGrid(1, 1);
					cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
					bombaFila << <dimGrid, dimBlock >> > (tablero_d, anchura, altura, dificultad, fila, devStates);
					break;
				}
				case 2:
				{
					std::cout << "Columna: ";
					std::cin >> columna;
					dim3 dimBlock(anchura, altura);
					dim3 dimGrid(1, 1);
					cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
					bombaColumna << <dimGrid, dimBlock >> >(tablero_d, anchura, altura, dificultad, columna, devStates);
					break;
				}
				case 3:
				{
					dim3 dimBlock(anchura, altura);
					dim3 dimGrid(1, 1);
					cudaMemcpy(tablero_d, tablero, size * sizeof(float), cudaMemcpyHostToDevice);
					bombaRotar << <dimGrid, dimBlock >> >(tablero_d, anchura, altura);
					break;
				}
				}
				break;
			}
			}
			cudaMemcpy(tablero, tablero_d, size * sizeof(float), cudaMemcpyDeviceToHost);
			break;
		}

		}

	}
	free(tablero);
	cudaFree(tablero_d);
	cudaFree(devStates);
	return 0;
}
