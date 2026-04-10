Your task is the creation of a new script, for being able to benchmark easily the best parameters to use with each of my models. 
I already have a script for loading models, you can get inspiration and informations needed from it : /home/neo/Documents/LLM_env/llama-launcher-with-model-parameters.py 

Your task it to do the same with llama.cpp/tools/llama-bench

# Python version

My use case is to be able to start in chain several models and find optimal gpu layer offload amount, context size, threads (...) in order to increase output speed. Output should be saved in an horodated result.md file.

You can find documentation in the folder of my llama.cpp clone at /home/neo/llama.cpp/tools/llama-bench

The script produced should be named /home/neo/Documents/LLM_env/llama-benchmark.py

# bash version 

Do the same, but this time in bash, i want to compare both versions. The script produced should be named /home/neo/Documents/LLM_env/llama-benchmark.sh
