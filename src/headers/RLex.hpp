#pragma once

#include <vector>

typedef enum {
    Keyword,
    Declaration,
    Type,
    Value
} TokenType;

typedef struct {
    TokenType token;
    const char *value;
} Token;

class Tokens {
    public:
        void AddToken(TokenType type, const char *value);
    private:
        std::vector<Token> TokenList;
};
