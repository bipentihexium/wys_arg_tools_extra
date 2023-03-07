/* Copyright (c) 2022 bipentihexium

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE. */

// commands for g++:
// debug:
// g++ -o playground wys_playground_cpp.cpp -Wall -Wextra -Wpedantic -g -march=native -std=c++11
// ./playground
// speed:
// g++ -o playground wys_playground_cpp.cpp -Wall -Wextra -Wpedantic -O3 -march=native -std=c++11
// ./playground
// note that the -std=c++11 can be changed to any newer version :)

#include <array>
#include <iostream>
#include <memory>
#include <mutex>
#include <set>
#include <thread>
#include "wys_lib_cpp.hpp"
#include "word_check.hpp"

constexpr unsigned int no_threads = 3;

constexpr auto used_data = data5;
constexpr unsigned int word_min_limit = 0;
constexpr unsigned int limit = 8;
constexpr float score_cutoff = -1000.05f;

unsigned long int partial_results = 0;
unsigned int results = 0;
trie_node full_trie;
trie_node cutoff_trie;

std::mutex output_mut;
std::set<std::string> found_already;
void callback(const std::string &key) {
	std::string preview = humanscantsolvethis_decrypt(used_data, key);
	//float score = message_likeliness<false>(preview, full_trie);
	//partial_results++;
	//if (score > score_cutoff) {
	//	output_mut.lock();
	//	std::cout << key << ": {" << preview.substr(0, limit) << '#' << preview.substr(limit) << "} score: " << score << std::endl;
	//	output_mut.unlock();
	//	results++;
	//}
	partial_results++;
	if (found_already.find(preview) == found_already.end()) {
		float score = message_likeliness<false>(preview, full_trie);
		std::cout << key << ": {" << preview.substr(0, limit) << '#' << preview.substr(limit) << "} score: " << score << std::endl;
		found_already.emplace(preview);
		results++;
	}
}

unsigned int next_task;
std::mutex task_mut;
void search_thread(unsigned int id) {
	output_mut.lock();
	std::cerr << "thread " << id << " running" << std::endl;
	output_mut.unlock();
	task_mut.lock();
	while (next_task < 26 * 26) {
		unsigned int task = next_task++;
		task_mut.unlock();
		unsigned int skip1 = task / 26 + 1;
		unsigned int skip2 = task % 26 + 1;
		output_mut.lock();
		std::cerr << "thread " << id << " starting search at " <<
			static_cast<char>(skip1 + '@') << static_cast<char>(skip2 + '@') << "..." << std::endl;
		output_mut.unlock();
		check_start(used_data, cutoff_trie, limit, callback, skip1, skip2);
		output_mut.lock();
		std::cerr << '[' << next_task << '/' << (26*26) << "] thread " << id << " finished search at " <<
			static_cast<char>(skip1 + '@') << static_cast<char>(skip2 + '@') << "...; results so far: " << results << std::endl;
		output_mut.unlock();
		task_mut.lock();
	}
	task_mut.unlock();
	output_mut.lock();
	std::cerr << "thread " << id << " terminating - no tasks left" << std::endl;
	output_mut.unlock();
}

int main() {
	//std::cout << dontbother17_decrypt(data1) << std::endl;
	//std::cout << dontbother17_encrypt(text2) << std::endl;
	//std::cout << humanscantsolvethis_decrypt(data2) << std::endl;
	//std::cout << humanscantsolvethis_encrypt(text3) << std::endl;
	//std::cout << sheismymother_decrypt(data3) << std::endl;
	//std::cout << sheismymother_encrypt(text4) << std::endl;
	//std::cout << processingpowercheck_decrypt(data4) << std::endl;
	//std::cout << processingpowercheck_encrypt(text5) << std::endl;
	next_task = 0;
	
	std::cout << "[word finder]" << std::endl;
	std::cout << "[data: " << used_data << "]" << std::endl;
	std::cout << "[limit: " << limit << "]" << std::endl;
	full_trie = trie_node::load_file("./word_list.txt", 0);
	cutoff_trie = trie_node::load_file("./word_list.txt", word_min_limit);
	std::array<std::unique_ptr<std::thread>, no_threads - 1> other_threads;
	for (unsigned int i = 0; i < other_threads.size(); i++) {
		other_threads[i] = std::unique_ptr<std::thread>(new std::thread(search_thread, i + 1));
	}
	search_thread(0);
	for (unsigned int i = 0; i < other_threads.size(); i++) {
		other_threads[i]->join();
		other_threads[i].release();
	}
	unsigned long int cutoff = partial_results - results;
	float cutoff_rate = static_cast<float>(cutoff) / static_cast<float>(partial_results);
	std::cout << results << " results found (full " << partial_results << ", score cutoff " << cutoff << ", cutoff rate " << cutoff_rate << ")" << std::endl;
	std::cerr << results << " results found (full " << partial_results << ", score cutoff " << cutoff << ", cutoff rate " << cutoff_rate << ")" << std::endl;
	return 0;
}
