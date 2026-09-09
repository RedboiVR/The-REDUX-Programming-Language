#pragma once

#include <vector>
#include <string>

enum TokenType {
    Keyword,
    Declaration,
    Type,
    Value
};

struct Token {
    TokenType type;
    std::string val;
};

class TokenClass {
    public:
        void StoreToken(Token tkn);
        void PutTokensInTokenList(std::string ln);
        std::vector<Token> GetTokens();
    private:
        std::vector<Token> TokenList;
};
