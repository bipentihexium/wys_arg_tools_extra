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

#include <algorithm>
#include <array>
#include <iostream>
#include <set>
#include "wys_lib_cpp.hpp"
#include "word_check.hpp"

std::string rot(const std::string &s, unsigned int n) {
	std::string out(s);
	for (char &c : out) {
		if ('A' <= c && c <= 'Z') {
			c = static_cast<char>((c-'A'+n)%('Z'-'A')+'A');
		} else if ('a' <= c && c <= 'z') {
			c = static_cast<char>((c-'a'+n)%('z'-'a')+'a');
		}
	}
	return out;
}
std::string posrot(const std::string &s, unsigned int n) {
	return s.substr(n % s.size()) + s.substr(0, n % s.size());
}
std::string op(const std::string &s, unsigned int opid, unsigned int val) {
	switch (opid) {
	case 0:{ return rot(s, val); }
	case 1:{ return posrot(s, val); }
	case 2:{ return dontbother17_decrypt(s, val); }
	case 3:{ return dontbother17_encrypt(s, val); }
	case 4:{ std::string out(s.size(), '\0'); std::copy(s.rbegin(), s.rend(), out.begin()); return out; }
	default: return s;
	};
}
unsigned long results = 0;
std::array<unsigned int, 2> vals = { 7, 27 };
trie_node trie;
std::set<std::string> found_already;
void search(const std::string &s, unsigned int depth) {
	if (depth > 1) {
		for (const unsigned int &val : vals) {
			for (unsigned int opid = 0; opid < 5; opid++) {
				search(op(s, opid, val), depth-1);
			}
		}
	} else {
		if (found_already.find(s) == found_already.end()) {
			std::string preview = humanscantsolvethis_decrypt(data5, s);
			float score = message_likeliness<false>(preview, trie);
			std::cout << s << ": {" << preview << "} score: " << score << std::endl;
			found_already.emplace(s);
			results++;
		}
	}
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
	trie = trie_node::load_file("./word_list.txt", 0);
	std::cout << "[op_bruteforce]" << std::endl;
	constexpr const char *k = "XDYOYOY";
	std::cout << "[k: " << k << "]" << std::endl;
	std::cout << "[b]" << std::endl;
	for (unsigned int i = 0; i < 6; i++) {
		search(k, i);
		std::cerr << "[done depth " << i << "] " << results << " results" << std::endl;
	}
	std::cout << results << " results" << std::endl;
	std::cerr << results << " results" << std::endl;
	return 0;
}
