require 'spec_helper'

# The "bare include is safe" contexts below are the regression guard for the
# 3.0.0 blast-radius refactor: `include dconf` must only install the package.
describe 'dconf' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters (bare include)' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('dconf') }
        it { is_expected.to create_class('dconf::install') }
        it { is_expected.to create_package('dconf').with_ensure('installed') }

        it 'does not manage any dconf profile' do
          is_expected.not_to create_dconf__profile('Defaults')
          is_expected.not_to create_concat('/etc/dconf/profile/user')
          is_expected.not_to create_file('/etc/dconf/profile')
        end

        it 'does not manage any dconf settings or database directories' do
          is_expected.not_to create_dconf__settings('Defaults')
          is_expected.not_to create_file('/etc/dconf/db/Defaults.d')
          is_expected.not_to create_file('/etc/dconf/db/Defaults.d/defaults')
          is_expected.not_to contain_exec('dconf update Defaults')
        end
      end

      context 'with user_profile set' do
        let(:params) do
          {
            user_profile: {
              'user'   => { 'type' => 'user',   'order' => 1 },
              'local'  => { 'type' => 'system', 'order' => 20 },
              'site'   => { 'type' => 'system', 'order' => 30 },
              'distro' => { 'type' => 'system', 'order' => 40 },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_dconf__profile('Defaults').with_target('user') }
        it { is_expected.to create_dconf__profile('Defaults').with_entries(params[:user_profile]) }
        it { is_expected.to create_concat('/etc/dconf/profile/user') }
      end

      context 'with custom user settings' do
        let(:params) do
          {
            user_settings: {
              'org/gnome/desktop/media-handling' => {
                'automount' => { 'value' => false, 'lock' => false },
                'automount-open' => { 'value' => false },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_dconf__settings('Defaults').with_settings_hash(params[:user_settings]) }
        it { is_expected.to create_dconf__settings('Defaults').with_profile('Defaults') }

        it 'does not purge unmanaged files by default' do
          is_expected.to create_file('/etc/dconf/db/Defaults.d').with_purge(false)
        end
      end

      context 'with authselect => true' do
        let(:params) { { authselect: true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_file('/etc/dconf/db/distro.d/20-authselect') }
        it { is_expected.to create_file('/etc/dconf/db/distro.d/locks/20-authselect') }
      end
    end
  end
end
