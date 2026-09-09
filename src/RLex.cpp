#pragma once

#include "head/RLex.hpp"

void TokenClass::StoreToken(Token tkn){
    TokenList.push_back(tkn);
}
std::vector<Token> TokenClass::GetTokens(){
    return TokenList;
}
