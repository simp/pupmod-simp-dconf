require 'spec_helper'

describe 'dconf' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to create_class('dconf') }
      it { is_expected.to create_class('dconf::install') }
      it { is_expected.to create_package('dconf').with_ensure('installed') }
      it { is_expected.to create_dconf__profile('Defaults').with_target('user') }
      it {
        is_expected.to create_dconf__profile('Defaults').with_entries(
          {
            'user'   => {
              'type'  => 'user',
              'order' => 1
            },
            'local'  => {
              'type'  => 'system',
              'order' => 20
            },
            'site'   => {
              'type'  => 'system',
              'order' => 30
            },
            'distro' => {
              'type'  => 'system',
              'order' => 40
            }
          }
        )
      }

      context 'with custom user settings' do
        let(:params) {{
          :user_settings => {
            'org/gnome/desktop/media-handling' => {
              'automount' => { 'value' => false, 'lock' => false },
              'automount-open' => { 'value' => false }
            }
          }
        }}

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_dconf__settings('Defaults').with_settings_hash(params[:user_settings]) }
        it { is_expected.to create_dconf__settings('Defaults').with_profile('Defaults') }
      end
    end
  end
end
