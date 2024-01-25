#include <iostream>
#include <vector>
#include <ctime>
#include <cstdlib>

// Struktura do przechowywania rozwi�zania
struct Solution {
    int value;
    int weight;
    std::vector<int> items;

    Solution(int numItems) : value(0), weight(0), items(numItems, 0) {}

    void addItem(int itemIndex, int itemWeight, int itemValue) {
        items[itemIndex] = 1;
        weight += itemWeight;
        value += itemValue;
    }
};

Solution tabuSearch(int* weights, int* values, int capacity, int numItems, int tabuListSize, int maxIterations) {
    std::vector<int> tabuList(numItems, 0);
    Solution bestSolution(numItems);
    Solution currentSolution(numItems);

    for (int iter = 0; iter < maxIterations; iter++) {
        Solution localSolution = currentSolution;
        int itemToAdd = -1;
        int bestDelta = 0;

        for (int i = 0; i < numItems; i++) {
            if (localSolution.items[i] == 0) { 
                int deltaValue = values[i];
                int deltaWeight = weights[i];

                // Sprawd�, czy przedmiot mo�e by� dodany i nie jest na li�cie tabu
                if (localSolution.weight + deltaWeight <= capacity && tabuList[i] < iter) {
                    if (deltaValue > bestDelta) {
                        bestDelta = deltaValue;
                        itemToAdd = i;
                    }
                }
            }
        }

        if (itemToAdd != -1) {
            localSolution.addItem(itemToAdd, weights[itemToAdd], values[itemToAdd]);
            tabuList[itemToAdd] = iter + tabuListSize;

            if (localSolution.value > bestSolution.value) {
                bestSolution = localSolution;
            }
        }

        currentSolution = localSolution;
    }

    return bestSolution;
}


int main() {
    const int maxIters = 1000;
    const int tabuListSize = 10;
    const int N = 50; // Maksymalna warto�� dla wagi i warto�ci

    srand(time(0));

    for (double numItems = 1e4; numItems <= 3e4; numItems += 0.25*1e4) {
        int numItemsInt = static_cast<int>(numItems);
        int capacity = numItemsInt * 10; // Pojemno�� plecaka dziesi�� razy wi�ksza ni� liczba przedmiot�w

        int* weights = new int[numItemsInt]; // Dynamiczna alokacja pami�ci dla wag przedmiot�w
        int* values = new int[numItemsInt];  // Dynamiczna alokacja pami�ci dla warto�ci przedmiot�w

        // Inicjalizacja wag i warto�ci przedmiot�w
        for (int i = 0; i < numItemsInt; i++) {
            weights[i] = rand() % (N + 1);
            values[i] = rand() % (N + 1);
        }

        clock_t start = clock();

        Solution bestGlobalSolution(numItemsInt);
        for (int iter = 0; iter < maxIters; iter++) {
            Solution localSolution = tabuSearch(weights, values, capacity, numItemsInt, tabuListSize, iter);
            if (localSolution.value > bestGlobalSolution.value) {
                bestGlobalSolution = localSolution;
            }
        }

        clock_t end = clock(); 
        double elapsed = double(end - start) / CLOCKS_PER_SEC * 1000; // Obliczenie czasu wykonania

        std::cout << "Number of items: " << numItemsInt << ", Best global solution value: " << bestGlobalSolution.value << ", Execution Time: " << elapsed << " ms" << std::endl;

        delete[] weights; 
        delete[] values;  
    }

    return 0;
}