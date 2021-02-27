%{
    #include <iostream>
    #include <iomanip>
    #include <fstream>
    #include <string>
    #include "string.h"
    #include <vector>

    extern int yylex();
    int yyerror(const char *s);

    struct Symbol
    {
      char name = 0;
      int value = 0;
    };

    struct AST
    {
        int type = 0;
        int value = 0;
        AST * left;
        AST * right;
    };
    enum AST_Type
    {
      EMPTY,
      LIST,
      CONDITION,
      IF_ELSE,
      PROCEDURE
    };

    extern std::vector<Symbol> symbols;
    int * getValue(char symbol);
    void assign(char symbol, int value);

    void freeAST(AST * ast);
    AST * makePrimary(int type, int left);
    AST * makeSingleWithValue(int type, int value, AST * ast);
    AST * makeAST(int type, AST * left, AST * right);
    AST * makeASTWithValue(int type, int value, AST * left, AST * right);
    void appendAST(AST * list, AST * stmt);
    int eval(AST * ast);

    enum ValueType
    {
      REGISTER,
      IMMEDIATE
    };
    struct Operand
    {
      int value = 0;
      ValueType type = REGISTER;
    };
    int registerNumber(char symbol);
    int getTemporary();
    void addToInstruction(long & instruction, int value, int sizeOfValue);
    Operand createExpressionInstruction(AST * ast, int immediateOpcode, int immediateLayout, int registerOpcode, int registerLayout);
    Operand compile(AST * ast);
    std::vector<long> program;
%}

%define api.prefix {pascal}

%union
{
    int ival;
    char * sval;
    struct AST * astval;
}

%token <sval> IDENTIFIER
%token <ival> NUM
%token VAR INTEGER
%token PROGRAM BEGIN_BLOCK END_BLOCK
%token PERIOD SEMICOLON COLON LEFT_PAREN RIGHT_PAREN COMMA
%token ASSIGN GREATER_THAN LESS_THAN PLUS MINUS MULT DIV
%token IF THEN ELSE WHILE DO

%right THEN ELSE

%type <astval> primary_expression multiplicative_expression additive_expression expression
%type <astval> control_flow statement statement_list block1 block
%type <sval> variable procid

%%
pascal_program: PROGRAM IDENTIFIER SEMICOLON block PERIOD                       {
                                                                                  printf("Parse Successful\n");
                                                                                  printf("Begin compilation:\n");
                                                                                  compile($4);
                                                                                  freeAST($4);

                                                                                  for (auto instruction : program)
                                                                                  {
                                                                                    std::cout << std::hex << instruction << std::endl;
                                                                                  }

                                                                                  std::ofstream writer("pascal.lwis");
                                                                                  for (auto instruction : program)
                                                                                  {
                                                                                    writer << instruction << std::endl;
                                                                                  }
                                                                                }
;

block: block1                                                                   {$$ = $1;}
| variable_declaration SEMICOLON block1                                         {$$ = $3;}
;

block1: BEGIN_BLOCK statement_list END_BLOCK                                    {
                                                                                  printf("Main block\n");
                                                                                  $$ = $2;
                                                                                }
;

variable_declaration: VAR variableid_list COLON INTEGER
| variable_declaration SEMICOLON variableid_list COLON INTEGER
;

variableid_list: IDENTIFIER                                                     {printf("Variable declaration=%s\n", $1);}
| variableid_list COMMA IDENTIFIER                                              {printf("Variable declaration=%s\n", $3);}
;

statement_list: statement                                                       {$$ = makeAST(LIST, $1, nullptr);}
| statement_list SEMICOLON statement                                            {
                                                                                  appendAST($1, makeAST(LIST, $3, nullptr));
                                                                                }
;

statement:                                                                      {
                                                                                  printf("Empty statement\n");
                                                                                  $$ = makeAST(EMPTY, nullptr, nullptr);
                                                                                }
| variable ASSIGN expression                                                    {
                                                                                  printf("Assignment statement\n");
                                                                                  $$ = makeSingleWithValue(ASSIGN, $1[0], $3);
                                                                                }
| BEGIN_BLOCK statement_list END_BLOCK                                          {printf("Code block\n"); $$ = $2;}
| control_flow                                                                  {$$ = $1;}
| procid LEFT_PAREN expression RIGHT_PAREN                                      {
                                                                                  printf("Function with parameters=%s\n", $1);

                                                                                  // I guess negative characters are a thing
                                                                                  if (strcmp("writeln", $1) == -'(')
                                                                                  {
                                                                                    $$ = makeAST(PROCEDURE, $3, nullptr);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Function not recognized");
                                                                                  }
                                                                                }
;

control_flow: IF expression THEN statement                                      {
                                                                                  printf("If statement\n");
                                                                                  $$ = makeAST(CONDITION, $2, makeAST(IF_ELSE, $4, nullptr));
                                                                                }
| IF expression THEN statement ELSE statement                                   {
                                                                                  printf("If-else statement\n");
                                                                                  $$ = makeAST(CONDITION, $2, makeAST(IF_ELSE, $4, $6));
                                                                                }
| WHILE expression DO statement                                                 {
                                                                                  printf("While statement\n");
                                                                                  $$ = makeAST(WHILE, $2, $4);
                                                                                }
;

variable: IDENTIFIER                                                            {printf("Variable=%c\n", $1[0]); $$ = $1;}
;

expression: expression GREATER_THAN additive_expression                         {
                                                                                  $$ = makeAST(GREATER_THAN, $1, $3);
                                                                                  printf("Greater than\n");
                                                                                }
| expression LESS_THAN additive_expression                                      {
                                                                                  $$ = makeAST(LESS_THAN, $1, $3);
                                                                                  printf("Less than\n");
                                                                                }
| additive_expression                                                           {
                                                                                  $$ = $1;
                                                                                }
;

additive_expression: additive_expression PLUS multiplicative_expression         {
                                                                                  printf("Addition\n");
                                                                                  $$ = makeAST(PLUS, $1, $3);
                                                                                }
| additive_expression MINUS multiplicative_expression                           {
                                                                                  printf("Subtraction\n");
                                                                                  $$ = makeAST(MINUS, $1, $3);
                                                                                }
| multiplicative_expression                                                     {$$ = $1;}
;

multiplicative_expression: multiplicative_expression MULT primary_expression      {
                                                                                    printf("Multiplication\n");
                                                                                    $$ = makeAST(MULT, $1, $3);
                                                                                  }
| multiplicative_expression DIV primary_expression                                {
                                                                                    printf("Division\n");
                                                                                    $$ = makeAST(DIV, $1, $3);
                                                                                  }
| primary_expression                                                              {$$ = $1;}
;

primary_expression: variable                                                    {
                                                                                  int * result = getValue($1[0]);
                                                                                  if (result[0] == 0)
                                                                                  {
                                                                                    $$ = makePrimary(VAR, $1[0]);
                                                                                  }
                                                                                  else
                                                                                  {
                                                                                    yyerror("Variable not found");
                                                                                  }
                                                                                }
| NUM                                                                           {
                                                                                  printf("Integer=%d\n", $1);
                                                                                  $$ = makePrimary(NUM, $1);
                                                                                }
;

procid: IDENTIFIER                                                              {$$ = $1;}
;
%%

void assign(char symbol, int value)
{
  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol)
    {
      symbols[i].value = value;
    }
  }
}

int * getValue(char symbol)
{
  static int result[2];
  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol)
    {
      result[0] = 0;
      result[1] = symbols[i].value;
      return result;
    }
  }

  result[0] = -1;
  result[1] = 0;
  return result;
}

void freeAST(AST * ast)
{
  if (ast->left != nullptr)
  {
    freeAST(ast->left);
  }

  if (ast->right != nullptr)
  {
    freeAST(ast->right);
  }

  free(ast);
}

AST * makePrimary(int type, int left)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->value = left;
  ast->left = nullptr;
  ast->right = nullptr;

  return ast;
}

AST * makeSingleWithValue(int type, int value, AST * ast)
{
  AST * stmt = makeASTWithValue(type, value, ast, nullptr);

  return stmt;
}

AST * makeAST(int type, AST * left, AST * right)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->left = left;
  ast->right = right;

  return ast;
}

AST * makeASTWithValue(int type, int value, AST * left, AST * right)
{
  AST * ast = (AST *)malloc(sizeof(AST));
  ast->type = type;
  ast->value = value;
  ast->left = left;
  ast->right = right;

  return ast;
}

void appendAST(AST * list, AST * stmt)
{
  AST * tail = list;
  while(tail->right != nullptr)
  {
    tail = tail->right;
  }

  tail->right = stmt;
}

int eval(AST * ast)
{
  int result = 0;

  if (ast != nullptr)
  {
    /* printf("Current: %c, Value: %d Left: %c, Right: %c\n", ast->type, ast->value, left, right); */
    switch (ast->type)
    {
      //Primary value-holders
      case NUM: result = ast->value;
      break;
      case VAR: result = getValue(ast->value)[1];
      break;

      //Expressions
      case GREATER_THAN: result = eval(ast->left) > eval(ast->right);
      break;
      case LESS_THAN: result = eval(ast->left) < eval(ast->right);
      break;
      case PLUS: result = eval(ast->left) + eval(ast->right);
      break;
      case MINUS: result = eval(ast->left) - eval(ast->right);
      break;
      case MULT: result = eval(ast->left) * eval(ast->right);
      break;
      case DIV: result = eval(ast->left) / eval(ast->right);
      break;

      //Statements
      case ASSIGN:
        result = eval(ast->left);
        assign(ast->value, result);
      break;
      case PROCEDURE:
        printf("%d\n", eval(ast->left));
      break;
      case CONDITION:
        result = eval(ast->left);
        ast->right->value = result;
        eval(ast->right);
      break;
      case IF_ELSE:
        if (ast->value)
        {
          eval(ast->left);
        }
        else
        {
          eval(ast->right);
        }
      break;
      case WHILE:
        while(eval(ast->left))
        {
          eval(ast->right);
        }
      break;
      case LIST:
        eval(ast->left);
        eval(ast->right);
      break;
    }
  }

  return result;
}

int registerNumber(char symbol)
{
  for (size_t i = 0; i < symbols.size(); ++i)
  {
    if (symbols[i].name == symbol)
    {
      return i + 2;
    }
  }

  return 0;
}

int getTemporary()
{
  if (symbols.size() < 254)
  {
    symbols.push_back(Symbol());
  }

  return symbols.size() + 2;
}

void addToInstruction(long & instruction, int value, int sizeOfValue)
{
  instruction = instruction << sizeOfValue;
  instruction = instruction | value;
}

Operand createExpressionInstruction(AST * ast, int immediateOpcode, int immediateLayout, int registerOpcode, int registerLayout)
{
  Operand operand;
  Operand left;
  Operand right;
  long instruction = 0;

  operand.type = REGISTER;
  operand.value = getTemporary();
  left = compile(ast->left);
  right = compile(ast->right);
  if (left.type == IMMEDIATE)
  {
    // Build an instruction that stores the left operand in a temp register
    addToInstruction(instruction, left.value, 0);
    left.value = getTemporary();
    addToInstruction(instruction, left.value, 8);
    addToInstruction(instruction, 0, 8);
    addToInstruction(instruction, 0x3, 8);
    program.push_back(instruction);
    instruction = 0;
  }

  // Build instruction
  addToInstruction(instruction, right.value, 0);
  addToInstruction(instruction, left.value, 8);
  addToInstruction(instruction, operand.value, 8);

  if (right.type == IMMEDIATE)
  {
    addToInstruction(instruction, immediateOpcode, 8);
    addToInstruction(instruction, immediateLayout, 8);
  }
  else
  {
    addToInstruction(instruction, registerOpcode, 8);
    addToInstruction(instruction, registerLayout, 8);
  }

  program.push_back(instruction);

  if (left.type == IMMEDIATE)
  {
    /* std::cout << "Symbol table size: " << symbols.size() << " Value: " << left.value << std::endl;
    symbols.erase(symbols.begin() + left.value); */
  }

  return operand;
}

Operand compile(AST * ast)
{
  Operand operand;
  Operand left;
  Operand right;
  long instruction = 0;

  if (ast != nullptr)
  {
    /* printf("Current: %c, Value: %d Left: %c, Right: %c\n", ast->type, ast->value, left, right); */
    switch (ast->type)
    {
      //Primary value-holders
      case NUM:
        operand.type = IMMEDIATE;
        operand.value = ast->value;
      break;
      case VAR:
        operand.type = REGISTER;
        operand.value = registerNumber(ast->value);
      break;

      //Expressions
      case GREATER_THAN: operand = createExpressionInstruction(ast, 0xC, 0x4, 0x1, 0x2);
      break;
      case LESS_THAN: operand = createExpressionInstruction(ast, 0xC, 0x4, 0x0, 0x2);
      break;
      case PLUS: operand = createExpressionInstruction(ast, 0x2, 0x4, 0x2, 0x5);
      break;
      case MINUS: operand = createExpressionInstruction(ast, 0x3, 0x4, 0x3, 0x5);
      break;
      case MULT: operand = createExpressionInstruction(ast, 0x4, 0x4, 0x0, 0x5);
      break;
      case DIV:
        operand.type = REGISTER;
        operand.value = getTemporary();
        left = compile(ast->left);
        right = compile(ast->right);
        if (left.type == IMMEDIATE)
        {
          // Build an instruction that stores the left operand in a temp register
          addToInstruction(instruction, left.value, 0);
          left.value = getTemporary();
          addToInstruction(instruction, left.value, 8);
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x3, 8);
          program.push_back(instruction);
        }

        // Build instruction
        addToInstruction(instruction, right.value, 0);
        addToInstruction(instruction, left.value, 8);

        if (left.type == IMMEDIATE)
        {
          /* symbols.erase(symbols.begin() + left.value); */
        }

        left.value = getTemporary();
        addToInstruction(instruction, left.value, 8);
        /* symbols.erase(symbols.begin() + left.value); */
        addToInstruction(instruction, operand.value, 8);

        if (right.type == IMMEDIATE)
        {
          addToInstruction(instruction, 0x5, 8);
          addToInstruction(instruction, 0x4, 8);
        }
        else
        {
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x5, 8);
        }

        program.push_back(instruction);
      break;

      //Statements
      case ASSIGN:
        left = compile(ast->left);

        if (left.type == IMMEDIATE)
        {
          addToInstruction(instruction, left.value, 0);
          addToInstruction(instruction, registerNumber(ast->value), 8);
          addToInstruction(instruction, 0, 8);
          addToInstruction(instruction, 0x3, 8);
        }
        else if (left.type == REGISTER)
        {
          addToInstruction(instruction, registerNumber(ast->value), 0);
          addToInstruction(instruction, 0, 16);
          addToInstruction(instruction, left.value, 8);
          addToInstruction(instruction, 0x7, 8);
          addToInstruction(instruction, 0x5, 8);
        }

        program.push_back(instruction);
      break;
      case PROCEDURE:
        left = compile(ast->left);
        addToInstruction(instruction, left.value, 0);
        addToInstruction(instruction, 0, 8);
        addToInstruction(instruction, 0x1, 8);
        program.push_back(instruction);
      break;
      case CONDITION:
        /* instruction = eval(ast->left);
        eval(ast->right); */
      break;
      case IF_ELSE:
        /* if (ast->value)
        {
          eval(ast->left);
        }
        else
        {
          eval(ast->right);
        } */
      break;
      case WHILE:
        /* while(eval(ast->left))
        {
          eval(ast->right);
        } */
      break;
      case LIST:
        compile(ast->left);
        compile(ast->right);
      break;
    }
  }

  return operand;
}

int main()
{
	pascalparse();
	return 0;
}

int yyerror(const char * s)
{
	fprintf(stderr, "Parse error: %s\n", s);
  return -1;
}
