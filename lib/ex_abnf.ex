defmodule ABNF do
  @moduledoc """
  Main module. ABNF parser as described in [RFC4234](https://tools.ietf.org/html/rfc4234)
  and [RFC5234](https://tools.ietf.org/html/rfc5234)

      Copyright 2015 Marcelo Gornstein <marcelog@gmail.com>

      Licensed under the Apache License, Version 2.0 (the "License");
      you may not use this file except in compliance with the License.
      You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

      Unless required by applicable law or agreed to in writing, software
      distributed under the License is distributed on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
      See the License for the specific language governing permissions and
      limitations under the License.
  """

  alias ABNF.Grammar, as: Grammar
  alias ABNF.Interpreter, as: Interpreter
  alias ABNF.CaptureResult, as: CaptureResult
  require Logger

  @doc """
  Optional __using__ macro for putting ABNF grammar etc in the module calling us:

  * a simple parse("rulename", 'code', %State{}) function calling ABNF.apply passing ourselve as grammar
  * rule("rulename") returning the ABNF AST for that specific rule
  * all inline Elixir functions

    ## Example:

      iex> defmodule Basic do use ABNF, grammar_file: "test/resources/basic.abnf" end
      iex> Basic.parse "string1", 'test'
      %ABNF.CaptureResult{input: 'test', rest: [], state: %{}, string_text: 'test',
       string_tokens: ['test'],
        values: [[[[['t']]], [[['e']]], [[['s']]], [[['t']]]]]}
  """
  defmacro __using__(opts) do
    quote do
      input = cond do
        (file = unquote(opts[:grammar_file])) ->
          data = File.read!(file)
          to_charlist(data)
        true ->
          raise ArgumentError, "Missing use option :grammar_file"
      end
      {grammar, funs} = case Grammar.rulelist input, module: __MODULE__, create_module: false do
        {grammar, '', funs} -> {grammar, funs}
        {_grammar, rest, _funs} -> throw {:incomplete_parsing, rest}
        _ -> throw {:invalid_grammar, input}
      end
      # add parse, grammar rule("name") and -inline Elixir functions to ourself
      def parse(rule, input, state \\ %{}), do:
        ABNF.apply(__MODULE__, rule, input, state)
      Enum.each grammar, fn({name, rule}) ->
        ABNF.defrule(name, Macro.escape(rule))
      end
      Code.eval_quoted funs, [], __ENV__
    end
  end

  @doc false
  defmacro defrule(name, value) do
    quote bind_quoted: [name: name, value: value] do
      def rule(unquote(name)), do: unquote(value)
    end
  end

  @doc """
  Loads a set of abnf rules from a file.
  """
  @spec load_file(String.t) :: Grammar.t | no_return
  def load_file(file) do
    data = File.read! file
    load to_char_list(data)
  end

  @doc """
  Returns the abnf rules found in the given char list.
  """
  @spec load([byte]) :: Grammar.t | no_return
  def load(input) do
    case Grammar.rulelist input do
      {rules, ''} -> rules
      {_rlist, rest} -> throw {:incomplete_parsing, rest}
      _ -> throw {:invalid_grammar, input}
    end
  end

  @doc """
  Parses an input given a gramar, looking for the given rule.
  """
  @spec apply(Grammar.t, String.t, [byte], term) :: CaptureResult.t
  def apply(grammar, rule, input, state \\ nil) do
    Interpreter.apply grammar, rule, input, state
  end
end
