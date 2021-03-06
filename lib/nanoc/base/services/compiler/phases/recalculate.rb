module Nanoc::Int::Compiler::Phases
  # Provides functionality for (re)calculating the content of an item rep, without caching or
  # outdatedness checking.
  class Recalculate
    include Nanoc::Int::ContractsSupport

    def initialize(action_provider:, dependency_store:, compilation_context:)
      @action_provider = action_provider
      @dependency_store = dependency_store
      @compilation_context = compilation_context
    end

    contract Nanoc::Int::ItemRep, C::KeywordArgs[is_outdated: C::Bool] => C::Any
    def run(rep, is_outdated:) # rubocop:disable Lint/UnusedMethodArgument
      dependency_tracker = Nanoc::Int::DependencyTracker.new(@dependency_store)
      dependency_tracker.enter(rep.item)

      executor = Nanoc::Int::Executor.new(rep, @compilation_context, dependency_tracker)

      @compilation_context.snapshot_repo.set(rep, :last, rep.item.content)

      @action_provider.memory_for(rep).each do |action|
        case action
        when Nanoc::Int::ProcessingActions::Filter
          executor.filter(action.filter_name, action.params)
        when Nanoc::Int::ProcessingActions::Layout
          executor.layout(action.layout_identifier, action.params)
        when Nanoc::Int::ProcessingActions::Snapshot
          executor.snapshot(action.snapshot_name)
        else
          raise Nanoc::Int::Errors::InternalInconsistency, "unknown action #{action.inspect}"
        end
      end
    ensure
      dependency_tracker.exit
    end
  end
end
