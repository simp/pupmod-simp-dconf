require 'spec_helper'

describe 'dconf::profile', :type => :define do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      context 'with a set of entries' do
        let(:title) { 'test' }
        let(:params) {{
          :target => 'test',
          :entries => {
            'user' => {
              'type' => 'user',
              'order' => 1
            },
            'test' => {
              'type' => 'system',
              'order' => 200
            },
            'test2' => {
              'type' => 'service'
            },
            '/some/file/path' => {
              'type' => 'file'
            }
          },
          :base_dir => '/tmp/foo'
        }}

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to create_file(params[:base_dir]).with_ensure('directory') }

        it { is_expected.to create_concat("#{params[:base_dir]}/#{params[:target]}").with_order('numeric') }

        it {
          is_expected.to create_concat__fragment("dconf::profile::#{params[:target]}::user").with({
            :target  => "#{params[:base_dir]}/#{params[:target]}",
            :order   => params[:entries]['user']['order'],
            :content => "user-db:user\n"
          })
        }

        it {
          is_expected.to create_concat__fragment("dconf::profile::#{params[:target]}::test").with({
            :target  => "#{params[:base_dir]}/#{params[:target]}",
            :order   => params[:entries]['test']['order'],
            :content => "system-db:test\n"
          })
        }

        it {
          is_expected.to create_concat__fragment("dconf::profile::#{params[:target]}::test2").with({
            :target  => "#{params[:base_dir]}/#{params[:target]}",
            :order   => 15,
            :content => "service-db:test2\n"
          })
        }

        it {
          is_expected.to create_concat__fragment("dconf::profile::#{params[:target]}::/some/file/path").with({
            :target  => "#{params[:base_dir]}/#{params[:target]}",
            :order   => 15,
            :content => "file-db:/some/file/path\n"
          })
        }
      end
    end
  end
end
