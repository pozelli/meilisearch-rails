require 'support/models/queued_models'
require 'support/models/movie'

describe MeiliSearch::Rails do
  it 'is active by default' do
    expect(described_class).to be_active
  end

  describe '#deactivate!' do
    context 'without block' do
      before { described_class.deactivate! }

      after { described_class.activate! }

      it 'deactivates the requests until activate!-ed' do
        expect(described_class).not_to be_active
      end

      it 'responds with a black hole' do
        expect(described_class.client.foo.bar.now.nil.item.issue).to be_nil
      end

      it 'does not queue tasks' do
        expect do
          EnqueuedDocument.create! name: 'hello world'
        end.not_to raise_error
      end

      it 'does not run callbacks on save' do
        movie = Movie.new(title: 'Harry Potter')
        allow(movie).to receive(:ms_index!)
        movie.save

        expect(movie).not_to have_received(:ms_index!)
      end
    end

    context 'with a block' do
      it 'disables only around call' do
        described_class.deactivate! do
          expect(described_class).not_to be_active
        end

        expect(described_class).to be_active
      end

      it 'works in multi-threaded environments' do
        Threads.new(5, log: $stdout).assert(20) do |_i, _r|
          described_class.deactivate! do
            expect(described_class).not_to be_active
          end

          expect(described_class).to be_active
        end
      end
    end
  end
end
