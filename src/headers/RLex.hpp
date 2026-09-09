#pragma once

#include <vector>
#include <string>

typedef enum {
    Keyword,
    Declaration,
    Type,
    Value
} TokenType;

typedef struct {
    TokenType token;
    std::string value;
} Token;

class Tokens {
    public:
        void AddToken(TokenType type, std::string value);

        void Lex(std::string ln);
    private:
        std::vector<Token> TokenList;
};
