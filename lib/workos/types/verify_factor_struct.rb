# frozen_string_literal: true
# typed: strict

module WorkOS
  module Types
    # This VerifyFactorStruct acts as a typed interface
    # for the Factor class
    class VerifyFactorStruct < T::Struct
      const :challenge, T.nilable(T::Hash[Symbol, Object])
      const :valid, T::Boolean
    end
  end
end
