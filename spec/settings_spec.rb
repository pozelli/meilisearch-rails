require 'support/async_helper'
require 'support/models/book'
require 'support/models/people'
require 'support/models/restaurant'

describe MeiliSearch::Rails::IndexSettings do
  describe 'add_attribute' do
    context 'with a symbol' do
      it 'calls method for new attribute' do
        TestUtil.reset_people!

        People.create(first_name: 'Jane', last_name: 'Doe', card_number: 75_801_887)
        AsyncHelper.await_last_task

        result = People.raw_search('Jane')
        expect(result['hits'][0]['full_name']).to eq('Jane Doe')
      end
    end
  end

  describe 'faceting' do
    it 'respects max values per facet' do
      TestUtil.reset_books!

      4.times do
        Book.create! name: Faker::Book.title, author: Faker::Book.author,
                     genre: Faker::Book.unique.genre
      end

      genres = Book.distinct.pluck(:genre)

      results = Book.search('', { facets: ['genre'] })

      expect(genres.size).to be > 3
      expect(results.facets_distribution['genre'].size).to eq(3)
    end
  end

  describe 'typo_tolerance' do
    it 'does not return any record with type when disabled' do
      TestUtil.reset_movies!

      Movie.create(title: 'Harry Potter')

      expect(Movie.search('harry pottr', matching_strategy: 'all')).to be_empty
    end

    it 'searches with one typo min size' do
      TestUtil.reset_books!

      Book.create! name: 'The Lord of the Rings', author: 'me', premium: false, released: true
      results = Book.search('Lrod')
      expect(results).to be_empty

      results = Book.search('Rnigs')
      expect(results).to be_one
    end

    it 'searches with two typo min size' do
      TestUtil.reset_books!

      Book.create! name: 'Dracula', author: 'me', premium: false, released: true
      results = Book.search('Darclua')
      expect(results).to be_empty

      Book.create! name: 'Frankenstein', author: 'me', premium: false, released: true
      results = Book.search('Farnkenstien')
      expect(results).to be_one
    end
  end

  describe 'attributes_to_crop' do
    before(:all) do
      10.times do
        Restaurant.create(
          name: Faker::Restaurant.name,
          kind: Faker::Restaurant.type,
          description: Faker::Restaurant.description
        )
      end

      Restaurant.reindex!(MeiliSearch::Rails::IndexSettings::DEFAULT_BATCH_SIZE, true)
    end

    it 'includes _formatted object' do
      results = Restaurant.search('')
      raw_search_results = Restaurant.raw_search('')
      expect(results[0].formatted).not_to be_nil
      expect(results[0].formatted).to eq(raw_search_results['hits'].first['_formatted'])
      expect(results.first.formatted['description'].length).to be < results.first['description'].length
      expect(results.first.formatted['description']).to eq(raw_search_results['hits'].first['_formatted']['description'])
      expect(results.first.formatted['description']).not_to eq(results.first['description'])
    end
  end

  describe 'settings change detection' do
    let(:record) { Color.create name: 'dark-blue', short_name: 'blue' }

    context 'without changing settings' do
      it 'does not call update settings' do
        allow(Color.index).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).not_to have_received(:update_settings)
      end
    end

    context 'when settings have been changed' do
      it 'makes a request to update settings' do
        idx = Color.index
        task = idx.update_settings(
          filterable_attributes: ['none']
        )
        idx.wait_for_task task['taskUid']

        allow(idx).to receive(:update_settings).and_call_original

        record.ms_index!

        expect(Color.index).to have_received(:update_settings).once
      end
    end
  end
end
