module Xero
  class Token
    attr_reader :content
    def initialize(val)
      @content = val
    end

    def to_s
      "#{self.class.name}[#@content]"
    end
    alias :inspect :to_s
  end

  class WhitespaceToken < Token
    def self.pattern
      /\s+/
    end
  end

  class SemicolonToken < Token
    def self.pattern
      /;/
    end
  end

  class LabelToken < Token
    def self.pattern
      /[a-zA-Z']+/
    end
  end

  class OpToken < Token; end

  class ArrowToken < OpToken
    def self.pattern
      /->/
    end
  end

  class DotToken < OpToken
    def self.pattern
      /\./
    end
  end

  class ColonToken < OpToken
    def self.pattern
      /:/
    end
  end

  class Tokenizer
    def analyze(string)
      scanner = StringScanner.new(string)
      tokens = []
      halted = false
      until scanner.eos? || halted
        any_matched = false
        token_kinds.each do |token_kind|
          matched_token = scanner.scan(token_kind.pattern)
          if matched_token
            tokens << token_kind.new(matched_token)
            any_matched = true
            break
          end
        end
        halted = true if !any_matched
      end
      tokens
    end

    def token_kinds
      [ LabelToken, ArrowToken, WhitespaceToken, ColonToken, DotToken, SemicolonToken ]
    end
  end
end
