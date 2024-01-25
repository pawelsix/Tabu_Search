
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <curand_kernel.h>
#include <iostream>
#include <stdio.h>
#include <cstdlib>
#include <ctime>

__global__ void tabuSearchKernel(int* weights, int* values, int* solutions, int capacity, int numItems, int* tabuList, int tabuListSize, int maxIterations) {
    int index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index < numItems) {
        // Inicjalizacja najlepszego rozwiązania i rozwiązania lokalnego
        int bestSolutionValue = 0;
        int bestSolutionWeight = 0;
        int localSolutionValue = 0;
        int localSolutionWeight = 0;

        // Inicjalizacja listy tabu
        for (int i = 0; i < tabuListSize; i++) {
            tabuList[i] = 0;
        }

        for (int iter = 0; iter < maxIterations; iter++) {
            int itemToAdd = -1;
            int bestDelta = 0;

            // Przejrzyj wszystkie przedmioty i wybierz najlepszy do dodania/usunięcia
            for (int i = 0; i < numItems; i++) {
                int deltaValue = values[i] - localSolutionValue;
                int deltaWeight = weights[i] - localSolutionWeight;

                // Sprawdź, czy przedmiot może być dodany i nie jest na liście tabu
                if (deltaWeight + localSolutionWeight <= capacity && tabuList[i] < iter) {
                    if (deltaValue > bestDelta) {
                        bestDelta = deltaValue;
                        itemToAdd = i;
                    }
                }
            }

            // Aktualizacja rozwiązania lokalnego i najlepszego
            if (itemToAdd != -1) {
                localSolutionValue += values[itemToAdd];
                localSolutionWeight += weights[itemToAdd];
                tabuList[itemToAdd] = iter + tabuListSize; // Aktualizacja listy tabu

                if (localSolutionValue > bestSolutionValue) {
                    bestSolutionValue = localSolutionValue;
                    bestSolutionWeight = localSolutionWeight;
                    solutions[index] = itemToAdd; // Zapis najlepszego rozwiązania
                }
            }
        }
    }
}

int main() {
    const int numItems = 10000; // Liczba elementów
    const int capacity = numItems;  // Pojemność plecaka
    const int tabuListSize = 10; // Rozmiar listy tabu
    const int maxIterations = 1000; // Maksymalna liczba iteracji
    const int blockSizes[] = { 64, 128, 256, 512, 1024 }; // Rozmiary bloków do testowania
    const int numTests = sizeof(blockSizes) / sizeof(blockSizes[0]);

    int weights[numItems]; // Wagi przedmiotów
    int values[numItems];  // Wartości przedmiotów
    int solutions[numItems]; // Rozwiązania

    // Zmienne do przechowywania czasu
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    const int N = 50; // Maksymalna wartość dla wagi i wartości

    // Inicjalizacja generatora liczb losowych
    srand(time(0));

    // Inicjalizacja wag i wartości przedmiotów
    for (int i = 0; i < numItems; i++) {
        weights[i] = rand() % (N + 1); // Losowa waga od 0 do N
        values[i] = rand() % (N + 1);  // Losowa wartość od 0 do N
    }

    int* d_weights, * d_values, * d_solutions, * d_tabuList;

    // Alokacja pamięci na GPU
    cudaMalloc(&d_weights, numItems * sizeof(int));
    cudaMalloc(&d_values, numItems * sizeof(int));
    cudaMalloc(&d_solutions, numItems * sizeof(int));
    cudaMalloc(&d_tabuList, tabuListSize * sizeof(int));

    // Kopiowanie danych na GPU
    cudaMemcpy(d_weights, weights, numItems * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_values, values, numItems * sizeof(int), cudaMemcpyHostToDevice);

    // Uruchomienie kernela
    for (int i = 0; i < numTests; ++i) {
        dim3 blockSize = blockSizes[i]; // Rozmiar bloku
        dim3 gridSize((numItems + blockSize.x - 1) / blockSize.x); // Rozmiar siatki

        // Zmienne do przechowywania czasu
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);

        // Start pomiaru czasu
        cudaEventRecord(start);
        tabuSearchKernel <<<gridSize, blockSize>>> (d_weights, d_values, d_solutions, capacity, numItems, d_tabuList, tabuListSize, maxIterations);

        // Przeniesienie wyników do pamięci CPU i obliczenia
        int cpuBestCost = 0;
        cudaMemcpy(solutions, d_solutions, numItems * sizeof(int), cudaMemcpyDeviceToHost);
        // Koniec pomiaru czasu
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);

        float milliseconds = 0;
        cudaEventElapsedTime(&milliseconds, start, stop);

        for (int i = 0; i < numItems; i++) {
            if (solutions[i] != 0) {
                cpuBestCost += values[i]; // Sumowanie wartości przedmiotów w najlepszym rozwiązaniu
            }
        }

        std::cout << "Block size: " << blockSizes[i] << ", Best cost found: " << cpuBestCost << ", Execution time: " << milliseconds << " ms" << std::endl;

        cudaEventDestroy(start);
        cudaEventDestroy(stop);
    }

    // Sprzątanie
    cudaFree(d_weights);
    cudaFree(d_values);
    cudaFree(d_solutions);
    cudaFree(d_tabuList);

    return 0;
}