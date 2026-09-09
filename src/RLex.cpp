#pragma once
#include "headers/RLex.hpp"

// literally the only definition.
// man i love C++
void Tokens::AddToken(TokenType type, std::string value){
    TokenList.PushBack({type, value});
}
