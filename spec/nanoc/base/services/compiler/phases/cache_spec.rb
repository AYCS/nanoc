describe Nanoc::Int::Compiler::Phases::Cache do
  subject(:phase) do
    described_class.new(
      compiled_content_cache: compiled_content_cache,
      snapshot_repo: snapshot_repo,
      wrapped: wrapped,
    )
  end

  let(:compiled_content_cache) do
    Nanoc::Int::CompiledContentCache.new(items: [item])
  end

  let(:snapshot_repo) { Nanoc::Int::SnapshotRepo.new }

  let(:wrapped_class) do
    Class.new do
      def initialize(snapshot_repo)
        @snapshot_repo = snapshot_repo
      end

      def run(rep, is_outdated:) # rubocop:disable Lint/UnusedMethodArgument
        @snapshot_repo.set(rep, :last, Nanoc::Int::TextualContent.new('wrapped content'))
      end
    end
  end

  let(:wrapped) { wrapped_class.new(snapshot_repo) }

  let(:item) { Nanoc::Int::Item.new('item content', {}, '/donkey.md') }
  let(:rep) { Nanoc::Int::ItemRep.new(item, :latex) }

  describe '#run' do
    subject { phase.run(rep, is_outdated: is_outdated) }

    let(:is_outdated) { raise 'override me' }

    shared_examples 'calls wrapped' do
      it 'delegates to wrapped' do
        expect(wrapped).to receive(:run).with(rep, is_outdated: is_outdated)
        subject
      end

      it 'marks rep as compiled' do
        expect { subject }
          .to change { rep.compiled? }
          .from(false)
          .to(true)
      end

      it 'sends no notifications' do
        expect(Nanoc::Int::NotificationCenter).not_to receive(:post)
        subject
      end

      it 'updates compiled content cache' do
        expect { subject }
          .to change { compiled_content_cache[rep] }
          .from(nil)
          .to(last: some_textual_content('wrapped content'))
      end
    end

    context 'outdated' do
      let(:is_outdated) { true }
      include_examples 'calls wrapped'
    end

    context 'not outdated' do
      let(:is_outdated) { false }

      context 'cached compiled content available' do
        before do
          compiled_content_cache[rep] = { last: Nanoc::Int::TextualContent.new('cached') }
        end

        it 'reuses content from cache' do
          expect { subject }
            .to change { snapshot_repo.get(rep, :last) }
            .from(nil)
            .to(some_textual_content('cached'))
        end

        it 'marks rep as compiled' do
          expect { subject }
            .to change { rep.compiled? }
            .from(false)
            .to(true)
        end

        it 'does not change compiled content cache' do
          expect { subject }
            .not_to change { compiled_content_cache[rep][:last].string }
        end

        it 'sends notification' do
          expect(Nanoc::Int::NotificationCenter).to receive(:post).with(:cached_content_used, rep)
          subject
        end
      end

      context 'no cached compiled content available' do
        include_examples 'calls wrapped'
      end
    end
  end
end
