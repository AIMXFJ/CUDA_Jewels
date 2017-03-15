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

void eliminarJewels(float* tablero, float* jewels_eliminadas, int dificultad, int anchura, int altura) {
	int max = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	int final = 0;
	
	for (int i = 0; i < max*2; i++) {
		//printf("\ni:%i valor:%f\n",i,jewels_eliminadas[i]);
		if (jewels_eliminadas[i] < 0) {
			final = i;
			break;
		}
	}

	if (final == 0) final = max*2;

	//printf("\nFinal: %i\n", final);
	srand(time(NULL));

	if (jewels_eliminadas[0] != jewels_eliminadas[2]) {
		for (int y = jewels_eliminadas[1]; y < altura; y++) {
			//printf("A");
			for (int x = jewels_eliminadas[0]; x <= jewels_eliminadas[final - 2]; x++) {
				//printf("\nBUCLE X:%i  Y:%i\n", x, y);
				if (y + 1 < altura) {
					tablero[x + (y)*(anchura)] = tablero[x + (y + 1)*anchura];
					switch (dificultad) {
					case 1: {
						int randJewel = rand() % 4 + 1;
						tablero[x + (y+1)*anchura] = randJewel;
						break;
					}
					case 2: {
						int randJewel = rand() % 6 + 1;
						tablero[x + (y+1)*anchura] = randJewel;
						break;
					}
					case 3: {
						int randJewel = rand() % 8 + 1;
						tablero[x + (y+1)*anchura] = randJewel;
						break;
					}
					}
				}
				else {
					switch (dificultad) {
					case 1: {
						int randJewel = rand() % 4 + 1;
						tablero[x + y*anchura] = randJewel;
						break;
					}
					case 2: {
						int randJewel = rand() % 6 + 1;
						tablero[x + y*anchura] = randJewel;
						break;
					}
					case 3: {
						int randJewel = rand() % 8 + 1;
						tablero[x + y*anchura] = randJewel;
						break;
					}
					}
				}
			}
		}
	}else{
		int posicion = jewels_eliminadas[0] + jewels_eliminadas[1] * anchura;
		float valor = tablero[posicion];
		for (int y = jewels_eliminadas[1]; y < altura; y++) {
			//printf("A");
			for (int x = jewels_eliminadas[0]; x <= jewels_eliminadas[final - 2]; x++) {
				//printf("\nBUCLE X:%i  Y:%i\n", x, y);
				if (y < altura) {
					if (y >= jewels_eliminadas[final-2]) {
						tablero[x + (y-final/2)*(anchura)] = tablero[x + (y)*anchura];
						switch (dificultad) {
						case 1: {
							int randJewel = rand() % 4 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						case 2: {
							int randJewel = rand() % 6 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						case 3: {
							int randJewel = rand() % 8 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						}
					}
					else {
						switch (dificultad) {
						case 1: {
							int randJewel = rand() % 4 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						case 2: {
							int randJewel = rand() % 6 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						case 3: {
							int randJewel = rand() % 8 + 1;
							tablero[x + (y)*anchura] = randJewel;
							break;
						}
						}
					}
				}
			}
		}
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
		while ((x - i + y*anchura >= 0) && (x -i>=0) && tablero[x - i + y*anchura] == tablero[x + y*anchura]) {
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

		jewels_eliminadas[jewels_posibles_izq*2] = x;
		jewels_eliminadas[jewels_posibles_izq*2+1] = y;

		salto = 2;
		for (int k = 1; k <= jewels_posibles_der; k++) {
			jewels_eliminadas[salto + jewels_posibles_izq*2] = x + k;
			jewels_eliminadas[salto + jewels_posibles_izq*2 + 1] = y;
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

			jewels_eliminadas[jewels_posibles_abaj*2] = x;
			jewels_eliminadas[jewels_posibles_abaj*2+1] = y;

			salto = 2;
			for (int k = 1; k <= jewels_posibles_arrib; k++) {
				jewels_eliminadas[salto + jewels_posibles_abaj*2] = x;
				jewels_eliminadas[salto + jewels_posibles_abaj*2 + 1] = y + k;
				salto += 2;
			}
		}
	}

	/*for (int q = 0; q < 2 * max; q++) {
		if (q % 2 != 0) {
			printf(" y:%f\n", jewels_eliminadas[q]);
		}
		else {
			printf("| x:%f\n", jewels_eliminadas[q]);
		}
	}*/
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

	if (seleccion == 2)
		analisisTableroManual(dificultad, tablero, anchura, altura, jewel2_x, jewel2_y);
}

//Funcion CPU. TODO: Arreglar calculo de contiguos, posible fallo al contar
void analisisTableroAutomatico(int dificultad, float* tablero, int anchura, int altura) {
	int max = 0;
	int size = anchura*altura;
	int jewels_posibles_der = 0;

	if (altura >= anchura) max = altura;
	else max = anchura;

	//Solo se eliminan MAX jewels como mucho, se guardan sus x e y
	float* jewels_eliminadas = (float*)malloc(2 * max * sizeof(float));

	//Tablero auxiliar para la toma del mejor caso
	float* aux_tablero = (float*)malloc(altura * anchura * sizeof(float));

	for (int i = 0; i < max; i++) {
		jewels_eliminadas[i] = -1;
	}

	//printf("\nAUTOMATICO\n");

	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			jewels_posibles_der = 0;

			//Si tiene por la derecha
			if ((x + 2) < anchura) {
				if (((x + 2) + y*anchura <= size) && tablero[x + 2 + y*anchura] == tablero[x + y*anchura]) {
					int i = 2;
					while ((x + i + y*anchura <= size) && tablero[x + i + y*anchura] == tablero[x + y*anchura]) {
						jewels_posibles_der++;
						i++;
					}

					aux_tablero[x + y*anchura] = jewels_posibles_der + 1;
				}
				else {
					aux_tablero[x + y*anchura] = 1;
				}
			}
			else {
				aux_tablero[x + y*anchura] = 1;
			}
		}
	}

	int x_mejor = 0;
	int y_mejor = 0;
	int valor_mejor = 0;

	for (int y = 0; y < altura; y++) {
		for (int x = 0; x < anchura; x++) {
			if (aux_tablero[x + y*anchura] > valor_mejor) {
				x_mejor = x;
				y_mejor = y;
				valor_mejor = aux_tablero[x + y*anchura];
			}
		}
	}

	//printf("\nTablero Aux Automatico:\n");
	//printTablero(aux_tablero, anchura, altura);


	//printf("\nMejores valores: x:%i  y:%i  valor:%i\n",x_mejor,y_mejor,valor_mejor);

	intercambiarPosiciones(tablero, x_mejor, y_mejor, 4, anchura, altura, 1, dificultad);

	//Se puede eliminar
	if (valor_mejor >= 3) {
		jewels_eliminadas[0] = x_mejor;
		jewels_eliminadas[1] = y_mejor;

		int salto = 2;

		for (int j = 1; j <= (valor_mejor); j++) {
			jewels_eliminadas[salto] = x_mejor + j;
			jewels_eliminadas[salto + 1] = y_mejor;
			salto += 2;
		}
	}

	eliminarJewels(tablero, jewels_eliminadas, dificultad, anchura, altura);


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
		for (int iColm = 0; (columna - iColm) > 0; iColm++)
		{
			if ((columna - iColm - 1) < 0)
			{
				tablero[(iFila*anchura) + (columna - iColm)] = generarJewel(dificultad);
			}
			else {
				tablero[(iFila*anchura) + (columna - iColm)] = tablero[(iFila*altura) + (columna - iColm - 1)];
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

int main(int argc, char** argv) {
	//Matriz de tamaño variable de floats, un array de Altura*Anchura
	int anchura;
	int altura;
	int dificultad;
	char modo;
	bool automatico = true;
	int TILE_WIDTH = 16;
	int size;
	char ficheroGuardado[9] = "save.txt";
	bool encontrado = false;
	int seleccion;

	float *tablero;
	/* Valores por argumento*/
	if (argc == 1)
	{
		std::cout << "Anchura del tablero: ";
		std::cin >> anchura;

		std::cout << "Altura del tablero: ";
		std::cin >> altura;

		std::cout << "Elija dificultad: \n1.-Facil \n2.-Media \n3.-Dificil\n";
		std::cin >> dificultad;

		int seleccion;
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
	
	bool jugando = true;

	/* Establecer automatico como modo de juego */
	
	size = anchura*altura;
	tablero = (float*)malloc(size * sizeof(float));

	//Se inicializa la matriz
	generacionInicialRandomJewels(tablero, dificultad, anchura, altura);

	//Bucle principal del juego
	while (jugando) {

		printTablero(tablero, anchura, altura);

		int jewel1_x = 0;
		int jewel1_y = 0;
		int accion = 0;

		std::cout << "Acción a realizar:\n";
		std::cout << "(1) Intercambiar Jewels\n";
		std::cout << "(2) Guardar partida\n";
		std::cout << "(3) Cargar partida\n";
		std::cout << "(9) Usar una Bomba\n";
		std::cout << "(0) Exit\n";
		std::cout << "Elija accion: ";

		std::cin >> accion;

		switch (accion) {
		case 0: {
			free(tablero);
			return 0;
		}
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
			guardado(tablero, anchura, altura, dificultad, ficheroGuardado);
			std::cout << "Guardado correcto.\n";
			break;
		}
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
		case 9: {
			// Bomba
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
								bombaRotarCPU(tablero, anchura, altura, fila, columna);
							}
						}
					}
					break;
				}
				}

				break;
			}
			}
			break;
		}

		}

	}
	free(tablero);
	return 0;
}