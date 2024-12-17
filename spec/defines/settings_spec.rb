require 'spec_helper'

describe 'dconf::settings', type: :define do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with minimal parameters' do
        let(:title) { 'Enable lock delay' }
        let(:params) do
          {
            ensure: 'present',
            settings_hash: { 'org/gnome/desktop/screensaver' => { 'lock-delay' => { 'value' => true } } },
            profile: 'gdm',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_file('/etc/dconf/db/gdm.d/enable_lock_delay') }
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/enable_lock_delay [org/gnome/desktop/screensaver] lock-delay')
            .with_value('true')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/enable_lock_delay [org/gnome/desktop/screensaver] lock-delay')
            .with(
              section: 'org/gnome/desktop/screensaver',
              setting: 'lock-delay',
              value: true,
            )
        end
        it do
          is_expected.to create_file('/etc/dconf/db/gdm.d/locks/enable_lock_delay')
            .with_content('/org/gnome/desktop/screensaver/lock-delay')
        end
      end

      context 'a setting with many items' do
        let(:title) { 'Set wallpaper' }
        let(:params) do
          {
            ensure: 'present',
            profile: 'gdm',
            settings_hash: {
              'org/gnome/desktop/background' => {
                'picture-uri'     => { 'value' => '/home/test/Pictures/puppies.jpg' },
                'picture-options' => { 'value' => 'scaled' },
                'primary-color'   => { 'value' => '000000' },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/set_wallpaper [org/gnome/desktop/background] picture-uri')
            .with_value('/home/test/Pictures/puppies.jpg')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/set_wallpaper [org/gnome/desktop/background] picture-options')
            .with_value('scaled')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/set_wallpaper [org/gnome/desktop/background] primary-color')
            .with_value('000000')
        end
        it do
          is_expected.to create_file('/etc/dconf/db/gdm.d/locks/set_wallpaper')
            .with_content(
              [
                '/org/gnome/desktop/background/picture-uri',
                '/org/gnome/desktop/background/picture-options',
                '/org/gnome/desktop/background/primary-color',
              ].join("\n"),
            )
        end
      end

      context 'with one setting with lock => false' do
        let(:title) { 'Enable lock delay' }
        let(:params) do
          {
            ensure: 'present',
            settings_hash: {
              'org/gnome/desktop/screensaver' => {
                'lock-delay' => { 'value' => true, 'lock' => false },
              },
            },
            profile: 'gdm',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/enable_lock_delay [org/gnome/desktop/screensaver] lock-delay')
            .with_value('true')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/enable_lock_delay [org/gnome/desktop/screensaver] lock-delay')
            .with(
              section: 'org/gnome/desktop/screensaver',
              setting: 'lock-delay',
              value: true,
            )
        end
        it do
          is_expected.to create_file('/etc/dconf/db/gdm.d/locks/enable_lock_delay')
            .with_ensure('absent')
        end
      end

      context 'a setting with many items, and one unlocked' do
        let(:title) { 'Arbitrary Name' }
        let(:params) do
          {
            ensure: 'present',
            profile: 'gdm',
            settings_hash: {
              'org/gnome/desktop/screensaver' => {
                'lock-delay' => { 'value' => true, 'lock' => true },
              },
              'org/gnome/desktop/background' => {
                'picture-uri'     => { 'value' => '/home/test/Pictures/puppies.jpg', 'lock' => false },
                'picture-options' => { 'value' => 'scaled', 'lock' => :undef },
                'primary-color'   => { 'value' => '000000' },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/arbitrary_name [org/gnome/desktop/background] picture-uri')
            .with_value('/home/test/Pictures/puppies.jpg')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/arbitrary_name [org/gnome/desktop/background] picture-options')
            .with_value('scaled')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/arbitrary_name [org/gnome/desktop/background] primary-color')
            .with_value('000000')
        end
        it do
          is_expected.to create_file('/etc/dconf/db/gdm.d/locks/arbitrary_name')
            .with_content(
              [
                '/org/gnome/desktop/screensaver/lock-delay',
                '/org/gnome/desktop/background/picture-options',
                '/org/gnome/desktop/background/primary-color',
              ].join("\n"),
            )
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/arbitrary_name [org/gnome/desktop/screensaver] lock-delay')
            .with_value('true')
        end
        it do
          is_expected.to create_ini_setting('/etc/dconf/db/gdm.d/arbitrary_name [org/gnome/desktop/screensaver] lock-delay')
            .with(
              section: 'org/gnome/desktop/screensaver',
              setting: 'lock-delay',
              value: true,
            )
        end
      end

      context 'with two resources with different values' do
        let(:pre_condition) do
          <<~EOM
            dconf::settings { 'Other Arbitrary Name':
              ensure        => 'present',
              profile       => 'gdm',
              settings_hash => {
                'org/gnome/desktop/screensaver2' => {
                  'lock-delay' => { 'value' => true, 'lock' => true }
                }
              }
            }
          EOM
        end

        let(:title) { 'Arbitrary Name' }
        let(:params) do
          {
            ensure: 'present',
            profile: 'gdm',
            settings_hash: {
              'org/gnome/desktop/screensaver' => {
                'lock-delay' => { 'value' => true, 'lock' => true },
              },
              'org/gnome/desktop/background' => {
                'picture-uri'     => { 'value' => '/home/test/Pictures/puppies.jpg', 'lock' => false },
                'picture-options' => { 'value' => 'scaled', 'lock' => :undef },
                'primary-color'   => { 'value' => '000000' },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end
