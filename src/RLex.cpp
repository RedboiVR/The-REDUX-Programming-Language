#pragma once
#include "headers/RLex.hpp"

void Tokens::AddToken(TokenType type, std::string value){
    TokenList.PushBack({type, value});
}

/*
typedef enum {
    Keyword,
    Declaration,
    Type,
    Value
} TokenType;
*/
void Tokens::Lex(std::string ln){
    std::string StrChunk; // the value that'll be passed into a token
    TokenType decidedtype; // A decided type that'll be passed into a token
    char RecentCharacter; // the character that'll join into the StrChunk or listen for signals to change the type on the ready
    for(size_t i=0; i<ln.size(); i++){
        RecentCharacter = ln[i];
        switch(RecentCharacter){
            default:
                StrChunk += RecentCharacter;
                break;
            case ':':
                // Flush Token
                decidedtype = Type;
                break;
            
        }
    }
}
