# Elixir MCP SDK Macro Refactoring Issues (2025-04-05)

## Goal

Refactor the Elixir MCP SDK (`apps/mcp`) to provide a simpler, macro-based way for server implementations to define tools, similar to the TypeScript SDK's `server.tool(...)` pattern.

## Approach

1.  Define a `tool/3` macro within `MCP.Server` (or a dedicated `Macros` module).
2.  This macro should capture the tool's name, input schema, and implementation logic (as a `do` block).
3.  Use a `@before_compile` hook within `MCP.Server` to iterate over the registered tool definitions.
4.  The hook should generate the necessary `handle_list_tools/3` and `handle_tool_call/4` function implementations required by the `MCP.ServerBehaviour`.
5.  `handle_tool_call/4` would look up the tool definition, validate arguments against the schema, and execute the captured implementation logic.

## Challenges Encountered

Several attempts were made, primarily struggling with Elixir's macro system intricacies related to context, quoting, escaping, and code generation within the `@before_compile` hook:

1.  **Dynamic `case` Generation:** Initial attempts tried to dynamically generate a `case tool_name do ... end` statement within the `handle_tool_call/4` function by splicing clauses for each registered tool. This consistently led to syntax errors (`expected -> clauses`, `misplaced operator ->`), suggesting issues with how `unquote_splicing` interacts with the `case` macro structure in this context.
2.  **Macro Context (`__CALLER__` / `caller_env`):**
    *   Capturing the macro's calling environment (`__CALLER__`) within the `tool` macro is necessary if using `Code.eval_quoted/3` to execute the user's code block in its original context.
    *   Storing this environment (`caller_env`) and correctly passing/unquoting it within the nested `quote` blocks of the `@before_compile` hook proved difficult, leading to errors like `tried to unquote invalid AST: #Macro.Env<...>` or `undefined variable "caller_env"`. The exact rules for escaping/unquoting the environment object across these boundaries were unclear and led to repeated failures.
3.  **Storing/Accessing Tool Definitions:** Storing the tool definition (schema, block AST, caller env) in a module attribute (`@mcp_tools`) and accessing it correctly within the `@before_compile` hook also caused issues. Errors occurred due to confusion about whether the attribute held the direct map/tuple or its escaped AST representation at different points in the compilation process (`BadMapError`, `undefined variable "tool_definition"`).
4.  **Simplified Approach (Direct Injection):** An attempt was made to simplify by removing `Code.eval_quoted` and `caller_env`, instead directly injecting the user's code block AST (`block_ast`) into the generated private function. This also failed with `undefined variable` errors for `arguments`, `session_id`, etc., within the `tool` macro's `quote` block, indicating the `tool_definition` map itself wasn't being constructed correctly within the macro's expansion context.

## Current State (as of last attempt)

The project fails to compile with errors like `undefined variable "arguments"` originating from the `tool` macro expansion in `MCP.Server.Macros`, indicating persistent issues with variable scoping and how the `tool_definition` map is constructed and stored within the macro. These issues remain unresolved as focus shifted to fixing the client-server communication issues.

## Potential Solutions

1. **Binding Variables Explicitly**: Instead of relying on implicit scoping, explicitly bind required variables at each stage of the macro expansion.
   ```elixir
   quote bind_quoted: [arguments: var!(arguments), session_id: var!(session_id)] do
     # Access arguments and session_id safely here
   end
   ```

2. **Generating Function Bodies with String Interpolation**: Rather than complex AST manipulation, consider generating the function body as a string and then parsing it with `Code.string_to_quoted/1`. This is less elegant but can be easier to debug.

3. **Using Function References**: Instead of storing and evaluating code blocks, store function references and call them directly. This avoids many of the scoping issues.
   ```elixir
   defmacro tool(name, schema, block) do
     fn_name = String.to_atom("execute_tool_#{name}")
     quote do
       def unquote(fn_name)(arguments, session_id, request_id) do
         unquote(block)
       end
       # Register the tool with its implementing function
       @mcp_tools {unquote(name), unquote(schema), {__MODULE__, unquote(fn_name)}}
     end
   end
   ```

4. **Two-Phase Expansion**: Split the macro processing into two distinct phases - registering the tools during `use` phase, and then generating the implementations at `@before_compile` phase, ensuring cleaner separation of concerns.

## Next Steps

Taking into account the current focus on client-server communication issues, the macro refactoring efforts can be revisited later with the following approach:

1. Start with a more simplified implementation that prioritizes correctness over elegance
2. Implement a basic version using function references rather than AST manipulation
3. Add complexity gradually, with thorough testing at each step
4. Consider using `unquote_splicing/1` more carefully, especially in nested quote contexts
5. Create minimal test cases that isolate each macro feature to verify behavior
