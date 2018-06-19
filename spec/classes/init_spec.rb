require 'spec_helper'

describe 'dconf' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('dconf') }
        it { is_expected.to create_class('dconf::install') }
        it { is_expected.to create_package('dconf').with_ensure('present') }
      end
    end
  end
end
