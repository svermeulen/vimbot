module Vimbot
  class Server
    attr_reader :vim_binary, :vimrc, :gvimrc, :errors

    def initialize(options={})
      @errors = []
      set_vim_binary(options[:vim_binary])
      set_config_files(options[:vimrc], options[:gvimrc])
    end

    def start
      return if @pid

      system("start #{command_prefix} --nofork -u #{vimrc} -U #{gvimrc}")

      wait_until_up

      # Get process id by hackily sleeping then grepping ps
      sleep(6)
      output = `ps -W -a | grep \\\\vim.exe`
      match = output.split()[0].strip

      @pid = match.to_i

      print "using id = #{@pid}"
    end

    def stop
      return unless @pid
      remote_send "<Esc>:qall!<CR>"

      # this doesn't work on windows
      #Process.wait(@pid)
      @pid = nil
    end

    def remote_send(command)
      #print "Executing #{command_prefix} --remote-send #{command}"
      output, error = Open3.capture3 "#{command_prefix} --remote-send #{escape(command)}"
      #print output
      #print error
      raise InvalidInput unless error.empty?
      nil
    end

    def remote_expr(expression)
      output, error = Open3.capture3 "#{command_prefix} --remote-expr #{escape(expression)}"
      #print output
      #print error
      raise InvalidExpression unless error.empty?
      output.gsub(/\n$/, "")
    end

    def name
      unless @name
        @@next_id = @@next_id + 1
        @name = "VIMBOT_#{@@next_id}"
      end
      @name
    end

    def up?
      running_server_names.include? name
    end

    private

    @@next_id = 0

    DEFAULT_VIM_BINARIES = %w(vim mvim gvim)
    EMPTY_VIMSCRIPT = File.expand_path("vim/empty.vim", Vimbot::GEM_ROOT)

    def wait_until_up
      sleep 0.25 until up?
    end

    def set_vim_binary(binary)
      if binary
        if binary_supports_server_mode?(binary)
          @vim_binary = binary
        else
          raise IncompatibleVim.new(binary)
        end
      else
        @vim_binary = DEFAULT_VIM_BINARIES.find {|binary| binary_supports_server_mode?(binary)}
        raise NoCompatibleVim unless @vim_binary
      end
    end

    def set_config_files(vimrc, gvimrc)
      @vimrc  = vimrc  || EMPTY_VIMSCRIPT
      @gvimrc = gvimrc || EMPTY_VIMSCRIPT
    end

    def binary_supports_server_mode?(binary)
      !(`#{binary} --help | grep -e --server`).empty?
    end

    #def escape(string)
      #Shellwords.escape(string)
    #end

    def escape(cmdline)
        '"' + cmdline.gsub(/\\(?=\\*\")/, "\\\\\\").gsub(/\"/, "\\\"").gsub(/\\$/, "\\\\\\").gsub("%", "%%") + '"'
    end

    def command_prefix
      "#{vim_binary} --servername #{name}"
    end

    def running_server_names
      `#{vim_binary} --serverlist`.split("\n")
    end
  end

  class InvalidExpression < Exception; end
  class InvalidInput < Exception; end

  class IncompatibleVim < Exception
    def initialize(binary)
      @binary = binary
    end

    def message
      "Vim binary '#{@binary}' does not support client-server mode."
    end
  end

  class NoCompatibleVim < Exception
    def message
      "Couldn't find a vim binary that supports client-server mode"
    end
  end
end

