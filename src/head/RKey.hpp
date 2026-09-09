#pragma once

#include <unordered_set>
#include <string>

class KeywordDef {
    public:
        inline static const std::unordered_set<std::string> Keywords {
            "var",
            "type"
        };
};
