#pragma once

#include "RLex.hpp"

void TokenClass::StoreToken(Token tkn){
    TokenList.push_back(tkn);
}
void TokenClass::PutTokensInTokenList(std::string ln){
    std::string Chunk;
    TokenType Guess_type = Keyword;
    char R_Char;
    bool KeywordDefined = false;
    for (size_t index = 0; index < ln.size(); index++) {
        R_Char = ln[index];

        switch(R_Char){
            default:
                Chunk.push_back(R_Char);
                break;

            case ':': // type
                TokenList.push_back({Guess_type, Chunk});
                Chunk = "";
                Guess_type = Type;
                break;
            case '=':
                TokenList.push_back({Guess_type, Chunk});
                Chunk = "";
                Guess_type = Value;
                break;
            case ' ':
                if (!Chunk.empty()) {
                    TokenList.push_back({Guess_type, Chunk});
                    Chunk = "";
                    if (!KeywordDefined) {
                        KeywordDefined = true;
                        Guess_type = Declaration;
                    }
                }
                break;
        }
        if (!Chunk.empty()){
            Chunk.push_back({Guess_type, Chunk});
        }

    }
}
std::vector<Token> TokenClass::GetTokens(){
    return TokenList;
}
