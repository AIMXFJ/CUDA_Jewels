#include <stdio.h>
#include <cuda_runtime.h>
#include <iostream>
#include <cstdlib>
#include <curand.h>
#include <curand_kernel.h>
#include <ctime>

#include <fstream>

//Analiza las propiedades de la tarjeta grafica para devolver el tamaño adecuado de tile, tambien trata el tamaño del tablero
int obtenerTileWidth(int anchura, int altura) {
	int min_medida = 0;

	if (anchura > altura) min_medida = anchura;
	else min_medida = altura;

	cudaDeviceProp propiedades;

	int max_threads = propiedades.maxThreadsPerBlock;

	if (anchura == altura) {	//Si la matriz es cuadrada, para no tener 1 solo bloque
		if (min_medida / 32 > 1 && max_threads == 1024) { //Solo si tiene 1024 hilos por bloque podra ser de 32x32
			return 32;
		}
		if (min_medida / 16 > 1) {
			return 16;
		}
		else if (min_medida / 8 > 1) {
			return 8;
		}
		else if (min_medida / 4 > 1) {
			return 4;
		}
		else if (min_medida / 2 > 1) {
			return 2;
		}
	}
	else {	//si la matriz no es cuadrada
		if (min_medida / 32 >= 1 && max_threads == 1024) {
			return 32;
		}
		if (min_medida / 16 >= 1) {
			return 16;
		}
		else if (min_medida / 8 >= 1) {
			return 8;
		}
		else if (min_medida / 4 >= 1) {
			return 4;
		}
		else if (min_medida / 2 >= 1) {
			return 2;
		}
	}
}

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

/*Recibe las coordenadas de las jewels a eliminar y mueve las filas que tiene que bajar a partir de ellas, emplea
una copia del tablero para evitar race conditions*/
__global__ void eliminarJewelsKernel(float* tablero_d, float* tablero_aux_d, float* jewels_eliminadas_d, int dificultad, int anchura, int altura, int final, int TILE_WIDTH) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	int block_x = blockIdx.x;
	int block_y = blockIdx.y;

	//Posicion real dentro del tablero
	tx += block_x * TILE_WIDTH;
	ty += block_y * TILE_WIDTH;

	//Array dinamico en memoria compartida, velocidad de accesoo mucho mayor que con global
	extern __shared__ float tablero_aux_shared[];

	float* tablero_shared = tablero_aux_shared;

	//Entre todos los hilos, los cuales ponen su posicion en el auxiliar compartido, rellenan por completo el auxiliar
	tablero_shared[tx + ty*anchura] = tablero_aux_d[tx + ty*anchura];

	//Esperan a que todos los hilos pongan su jewel, creando un tablero auxiliar completo en compartida.
	__syncthreads();

	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	if (jewels_eliminadas_d[0] != jewels_eliminadas_d[2] && tx >= jewels_eliminadas_d[0] && tx <= jewels_eliminadas_d[final - 2] && ty >= jewels_eliminadas_d[1]) {
		if (ty + 1 < altura) {
			float value = tablero_shared[tx + (ty + 1)*anchura];

			tablero_d[tx + (ty)*(anchura)] = value;
		}
		else {
			tablero_d[tx + ty*anchura] = -1;
		}
	}
	else {
		if (ty < altura && tx == jewels_eliminadas_d[0] && ty > jewels_eliminadas_d[1]) {
			float value = tablero_shared[tx + (ty)*anchura];
			tablero_d[tx + (ty - final / 2)*(anchura)] = value;
		}
		if (ty >= altura - final / 2 && ty < altura && tx == jewels_eliminadas_d[0]) {
			tablero_d[tx + (ty)*anchura] = -1;
		}
	}
}

/*Funcion que prepara y llama el kernel con su mismo nombre, genera todos los datos necesarios*/
void eliminarJewels(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura,int TILE_WIDTH) {
	float *tablero_d;
	float *jewels_eliminadas_d;
	float *tablero_aux_d;
	int size = anchura * altura * sizeof(float);
	int max = 0;

	//Para saber que medida es la más grande, ya que no se pueden eliminar más jewels seguidas que esa medida
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

	//Calcula cual es el ultimo valor escrito de las jewels a eliminar, ya que puede haber posiciones no escritas
	for (int i = 0; i < max * 2; i++) {
		if (jewels_eliminadas[i] < 0) {
			final = i;
			break;
		}
	}

	//En caso de que este completamente escrito
	if (final == 0) final = max * 2;

	//Cantidad de bloques de ancho de medida TILE_WIDTH
	int anch = ceil(anchura / TILE_WIDTH);

	//Cantidad de bloques de alto con medida TILE_WIDTH
	int alt = ceil(altura / TILE_WIDTH);

	//Configuracion de ejecucion
	dim3 dimBlock(TILE_WIDTH, TILE_WIDTH);
	dim3 dimGrid(alt, anch);

	eliminarJewelsKernel << <dimGrid, dimBlock, size>> > (tablero_d, tablero_aux_d, jewels_eliminadas_d, dificultad, anchura, altura, final,TILE_WIDTH);

	//Se recupera el tablero actualizado
	cudaMemcpy(tablero, tablero_d, size, cudaMemcpyDeviceToHost);

	//Se analiza y se añaden jewels nuevas en las posiciones vacias (-1)
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

//Analiza el movimiento manual, usando las coordenadas de la nueva posicion de la jewel seleccionada
void analisisTableroManual(int dificultad, float* tablero, int anchura, int altura, int x, int y, int TILE_WIDTH) {
	int max = 0;
	int size = anchura*altura;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan MAX jewels como mucho, se guardan sus x e y
	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));

	//Se inicializa a -1 àra saber hasta que punto se escribe
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
	eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura, TILE_WIDTH);
}

//Intercambia la jewel seleccionadas con la jewel en la dirección indicada
void intercambiarPosiciones(float* tablero, int jewel1_x, int jewel1_y, int direccion, int anchura, int altura, int seleccion, int dificultad, int TILE_WIDTH) {
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
	analisisTableroManual(dificultad, tablero, anchura, altura, jewel2_x, jewel2_y,TILE_WIDTH);
}

/*Escribe en un tablero auxiliar la cantidad de jewels que se eliminarian moviendo una jewel (x,y) hacia la derecha
paralelizable ya que todos los hilos (cada hilo 1 jewel) tienen que expandirse hacia la derecha para ver hasta donde llegarian a eliminar*/
__global__ void analisisTableroAutomaticoKernel(float *tablero_d, float *aux_d, int dificultad, int anchura, int altura, int TILE_WIDTH) {
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	int block_x = blockIdx.x;
	int block_y = blockIdx.y;

	//Posicion real dentro del tablero
	tx += block_x * TILE_WIDTH;
	ty += block_y * TILE_WIDTH;

	//Array dinamico en memoria compartida, velocidad de accesoo mucho mayor que con global
	extern __shared__ float tablero_aux_shared[];

	float* tablero_shared = tablero_aux_shared;

	//Entre todos los hilos, rellenan por completo el auxiliar en memoria compartida
	tablero_shared[tx + ty*anchura] = aux_d[tx + ty*anchura];

	//Esperan a que todos los hilos copien el valor, creando un tablero auxiliar completo en compartida.
	__syncthreads();

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

			tablero_shared[tx + ty*anchura] = jewels_posibles_der + 1;
		}
		else {
			tablero_shared[tx + ty*anchura] = 1;
		}
	}
	else {
		tablero_shared[tx + ty*anchura] = 1;
	}

	//Se esperan a que todos hayan calculado para actualizar la matriz a devolver
	__syncthreads();

	aux_d[tx + ty*anchura] = tablero_shared[tx + ty*anchura];
}


//Analiza la mejor opcion y la ejecuta en funcion de lo que devuelve el kernel
void analisisTableroAutomatico(int dificultad, float* tablero, int anchura, int altura, int TILE_WIDTH) {
	float *tablero_d;
	float *aux_d;
	float *aux;
	float *jewels_eliminadas_d;
	//Tamaño del tablero para asignar memoria
	int size = anchura * altura * sizeof(float);
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
	for (int p = 0; p < size; p++) {
		aux[p] = 1;
	}

	//Tablero a GPU
	cudaMalloc((void**)&tablero_d, size);
	cudaMemcpy(tablero_d, tablero, size, cudaMemcpyHostToDevice);
	//Auxiliar de conteo a GPU
	cudaMalloc((void**)&aux_d, size);
	cudaMemcpy(aux_d, aux, size, cudaMemcpyHostToDevice);

	//Cantidad de bloques de ancho de medida TILE_WIDTH
	int anch = ceil(anchura / TILE_WIDTH);

	//Cantidad de bloques de alto con medida TILE_WIDTH
	int alt = ceil(altura / TILE_WIDTH);

	//Configuracion de ejecucion
	dim3 dimBlock(TILE_WIDTH, TILE_WIDTH);
	dim3 dimGrid(alt, anch);

	//Inicio del kernel
	analisisTableroAutomaticoKernel <<<dimGrid,dimBlock,size>>> (tablero_d, aux_d, dificultad, anchura, altura, TILE_WIDTH);

	//Transfiere el resultado de la GPU al host
	cudaMemcpy(aux, aux_d, size, cudaMemcpyDeviceToHost);

	int x_mejor = 0;
	int y_mejor = 0;
	int valor_mejor = 0;

	//Se busca el movimiento con el mayor numero de jewels eliminadas
	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			if (aux[x+y*anchura] > valor_mejor) {
				valor_mejor = aux[x+y*anchura];
				x_mejor = x;
				y_mejor = y;
			}
		}
	}

	//Si se pueden eliminar se ejecuta el movimiento, con lo que ello conlleva
	if (valor_mejor >= 3) {
		intercambiarPosiciones(tablero, x_mejor, y_mejor, 4, anchura, altura, 1, dificultad,TILE_WIDTH);
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

	//Tamaño de los bloques a crear en CUDA
	int TILE_WIDTH = obtenerTileWidth(anchura, altura);

	//Bucle principal del juego
	while (jugando) {

		//Se muestra el tablero
		printTablero(tablero, anchura, altura);

		int jewel1_x = 0;
		int jewel1_y = 0;
		int accion = 0;

		//Se deja escoger eleccion, si es automatico hay que intercambiar cualquier jewel primero, aunque no se haga
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
					analisisTableroAutomatico(dificultad, tablero, anchura, altura, TILE_WIDTH);
				else
					intercambiarPosiciones(tablero, jewel1_x, jewel1_y, direccion, anchura, altura, seleccion, dificultad, TILE_WIDTH);
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