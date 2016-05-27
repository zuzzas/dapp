module Dapp
  module Builder
    class Shell < Base
      [:infra_install, :infra_setup, :app_install, :app_setup].each do |m|
        define_method(:"#{m}_commands") { config[m] }
        define_method(m) { send(:"#{m}_commands") }
        define_method(:"#{m}_key") { sha256([super, send(:"#{m}_commands")]) }
      end

      def app_install_key
        if dependency_file?
          sha256([super, app_install_commands])
        else
          super
        end
      end

      def app_setup_key
        if app_setup_file?
          sha256([super, app_setup_commands])
        else
          super
        end
      end
    end
  end
end
