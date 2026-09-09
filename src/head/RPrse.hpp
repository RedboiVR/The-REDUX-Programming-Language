#pragma once

#include <vector>
#include <string>

#include "../RLex.hpp"

enum Types {
    I64,
    U64,
    F64,
    I32,
    U32,
    F32,

    Byte,
    String,
    Char,
    Nil,

    Defined
};

struct ParentNodes {
    std::string value;
    ParentNodes* ParentNode = nullptr;
    std::vector<ParentNodes> ChildrenNodes;
};

class Parser {
    public:
        void AssembleAST(std::vector<Token> Tokens);
        std::vector<ParentNodes> AST;
};
