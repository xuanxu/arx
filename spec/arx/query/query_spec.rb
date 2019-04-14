require 'spec_helper'

describe Query do
  context '.initialize' do
    subject { Query }

    it { is_expected.to respond_to(:new).with(0..1).arguments }
    it { is_expected.to respond_to(:new).with_unlimited_arguments }

    context 'with no arguments' do
      it { expect(subject.new.to_s).to eq 'sortBy=relevance&sortOrder=descending' }
    end
    context 'with IDs' do
      context '1105.5379' do
        it { expect(subject.new('1105.5379').to_s).to eq 'sortBy=relevance&sortOrder=descending&id_list=1105.5379' }
      end
      context 'cond-mat/9609089' do
        it { expect(subject.new('cond-mat/9609089').to_s).to eq 'sortBy=relevance&sortOrder=descending&id_list=cond-mat/9609089' }
      end
      context '1105.5379, cond-mat/9609089 and cs/0003044' do
        it { expect(subject.new(*%w[1105.5379 cond-mat/9609089 cs/0003044]).to_s).to eq 'sortBy=relevance&sortOrder=descending&id_list=1105.5379,cond-mat/9609089,cs/0003044' }
      end
    end
    context 'with key-word arguments' do
      context '(invalid)' do
        context :sort_by do
          it { expect { subject.new(sort_by: 'invalid') }.to raise_error TypeError }
          it { expect { subject.new(sort_by: :invalid) }.to raise_error ArgumentError }
        end
        context :sort_order do
          it { expect { subject.new(sort_order: 'invalid') }.to raise_error TypeError }
          it { expect { subject.new(sort_order: :invalid) }.to raise_error ArgumentError }
        end
      end
      context '(valid)' do
        context :sort_by do
          Arx::Query::SORT_BY.each do |key, field|
            it { expect(subject.new(sort_by: key).to_s).to eq "sortBy=#{field}&sortOrder=descending" }
          end
        end
        context :sort_order do
          Arx::Query::SORT_ORDER.each do |key, field|
            it { expect(subject.new(sort_order: key).to_s).to eq "sortBy=relevance&sortOrder=#{field}" }
          end
        end
        context "sort_by and sort_order" do
          Arx::Query::SORT_BY.each do |sort_by_key, sort_by_field|
            Arx::Query::SORT_ORDER.each do |sort_order_key, sort_order_field|
              it { expect(subject.new(sort_by: sort_by_key, sort_order: sort_order_key).to_s).to eq "sortBy=#{sort_by_field}&sortOrder=#{sort_order_field}" }
            end
          end
        end
      end
    end
    context 'with IDs and key-word arguments' do
      it { expect(subject.new('1105.5379', 'cond-mat/9609089', sort_by: :date_submitted, sort_order: :ascending).to_s).to eq 'sortBy=submittedDate&sortOrder=ascending&id_list=1105.5379,cond-mat/9609089' }
    end
  end

  Query::CONNECTIVES.keys.each do |connective|
    context "##{connective}" do
      let(:query) { Query.new }

      context 'without a query string' do
        it do
          before = query.to_s
          expect(query.send(connective).to_s).to eq before
        end
      end
      context 'with a query string' do
        it { expect(query.title('Test').send(connective).to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22Test%22+#{Query::CONNECTIVES[connective]}" }
      end
      context 'with connective already present' do
        Query::CONNECTIVES.keys.each do |existing|
          it { expect(query.title('Test').send(existing).send(connective).to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22Test%22+#{Query::CONNECTIVES[existing]}" }
        end
      end
    end
  end

  Query::FIELDS.keys.each do |field|
    context "##{field}" do
      let(:query) { Query.new }

      context 'without a query string' do
        it { expect(query.send(field, 'cs.AI').to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=#{Query::FIELDS[field]}:%22cs.AI%22" }
      end
      context 'without a prior connective' do
        it { expect(query.title('test').send(field, 'cs.AI').to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22test%22+AND+#{Query::FIELDS[field]}:%22cs.AI%22" }
      end
      context 'with a prior connective' do
        Query::CONNECTIVES.keys.each do |connective|
          it { expect(query.title('test').send(connective).send(field, 'cs.AI').to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22test%22+#{Query::CONNECTIVES[connective]}+#{Query::FIELDS[field]}:%22cs.AI%22" }
        end
      end
      context 'exact: false' do
        it { expect(query.send(field, 'cs.AI', exact: false).to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=#{Query::FIELDS[field]}:cs.AI" }
      end
      context 'with multiple values' do
        it { expect(query.title('test').send(field, 'cs.AI', 'cs.LG').to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22test%22+AND+%28#{Query::FIELDS[field]}:%22cs.AI%22+AND+#{Query::FIELDS[field]}:%22cs.LG%22%29" }

        context 'exact: false' do
          it { expect(query.title('test').send(field, 'cs.AI', 'cs.LG', exact: false).to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22test%22+AND+%28#{Query::FIELDS[field]}:cs.AI+AND+#{Query::FIELDS[field]}:cs.LG%29" }
        end

        Query::CONNECTIVES.keys.each do |connective|
          context "connective: #{connective}" do
            it { expect(query.title('test').send(field, 'cs.AI', 'cs.LG', connective: connective).to_s).to eq "sortBy=relevance&sortOrder=descending&search_query=ti:%22test%22+AND+%28#{Query::FIELDS[field]}:%22cs.AI%22+#{Query::CONNECTIVES[connective]}+#{Query::FIELDS[field]}:%22cs.LG%22%29" }
          end
        end
      end
    end
  end

  context '#parenthesize' do
    subject { Query }

    it { expect(subject.new.send :parenthesize, 'test').to eq '%28test%29' }
    it { expect(subject.new.send :parenthesize, '(test)').to eq '%28(test)%29' }
  end
  context '#enquote' do
    subject { Query }

    it { expect(subject.new.send :enquote, 'test').to eq '%22test%22' }
    it { expect(subject.new.send :enquote, '"test"').to eq '%22"test"%22' }
  end
end