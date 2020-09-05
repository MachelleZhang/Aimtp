include FileTest
require "fileutils"

@module_arr = [] #所有模块名称
$dep_arr = [] #依赖名称
$sub_pod_path_hash = Hash.new #子模块的名称和来源路径
$sub_pod_hash = Hash.new #子模块的名称和去向路径
$sub_need_root_hash = Hash.new #子模块是否只拷贝内容不创建根文件夹
$sub_file_path_arr = [] #子模块Aimfile的路径，包含主模块的Aimfile


class Template
	attr_accessor :name
	@c_path_arr = []
	@tp_list = []
	
	class << self
		def config(name, &block)
			tp = new
			block.call(tp)
			tp.name = name
			@c_path_arr << name
			@tp_list << tp
			tp
		end

		def ret_all_module
			@c_path_arr
		end

		def find_by_name(tp_name)
      		@tp_list.find { |tp| tp.name == tp_name }
    	end
	end

	def sub(name, path, nRoot = 1)
		$sub_file_path_arr << 'sources/' + name + '/Aimfile'
		name_arr = name.split('/')
		mod_name = name_arr[name_arr.length - 1]
		$sub_pod_hash[mod_name] = path
		$sub_pod_path_hash[mod_name] = name
		$sub_need_root_hash[mod_name] = nRoot
	end

	def pod(name, options = {})
		if options == {}
			$dep_arr.push('"' + name + '"')
		elsif options.is_a? String
			$dep_arr.push('"' + name + '"' + ', ' + '"' + options + '"')
		elsif options.is_a? Hash
			o_str = options.to_s
			o_str = o_str.gsub(/[\{\}]/, '')
			$dep_arr.push('"' + name + '"' + ', ' + o_str)
		end
	end
end

def sub(name, path, nRoot = 1)
	$sub_file_path_arr << 'sources/' + name + '/Aimfile'
	name_arr = name.split('/')
	mod_name = name_arr[name_arr.length - 1]
	$sub_pod_hash[mod_name] = path
	$sub_pod_path_hash[mod_name] = name
	$sub_need_root_hash[mod_name] = nRoot
end

def pod(name, options = {})
	if options == {}
		$dep_arr.push('"' + name + '"')
	elsif options.is_a? String
		$dep_arr.push('"' + name + '"' + ', ' + '"' + options + '"')
	elsif options.is_a? Hash
		o_str = options.to_s
		o_str = o_str.gsub(/[\{\}]/, '')
		$dep_arr.push('"' + name + '"' + ', ' + o_str)
	end
end

# 循环深入文件夹
def traverse(from_path, to_path)
  	if File.directory?(from_path)  # 如果是目录
  		if !FileTest.exist?(to_path)
  			FileUtils.mkdir_p(to_path)
  		end
	    dir = Dir.open(from_path)
	    while name = dir.read
    		next if name == "."   # ※
      		next if name == ".."  # ※
      		traverse(from_path + "/" + name, to_path + "/" + name)
    	end
        dir.close
    else
        process_file(from_path, to_path)      # 处理文件
    end
end

# 拷贝文件
def process_file(from_path, to_path)
    FileUtils.cp(from_path, to_path)
end

# 删除模块中的Aimfile
def delete_config_file(path)
	file_name = path + '/Aimfile'
	if FileTest.exist?(file_name)
		FileUtils.rm(file_name)
	end
end

# 加载主模块Aimfile
main_aimfile_path = './Aimfile'
if !FileTest.exist?(main_aimfile_path)
	puts "Aimfile is not exist at current folder."
	exit
else 
	content = File.read main_aimfile_path
	eval content
end

# 将主模块的Aimfile单独添加进来，保证主工程的依赖也能引入
@module_arr = Template.ret_all_module.uniq
pro_dir_str = @module_arr[0]
$sub_file_path_arr << 'sources/' + pro_dir_str + '/Aimfile'
main_tp = Template.find_by_name(pro_dir_str)

# 拷贝模板主工程文件夹，主工程是@module_arr数组的第一个
traverse('sources/' + pro_dir_str, pro_dir_str)

# 加载子模块Aimfile
$sub_file_path_arr.each do |sub_str| 
	if !FileTest.exist?(sub_str)
		puts "#{sub_str} is not exist."
	else 
		sub_content = File.read sub_str
		eval sub_content
	end
end

# 依赖去重
$dep_arr = $dep_arr.uniq
@module_arr = Template.ret_all_module.uniq

# puts @module_arr
# puts $dep_arr
# puts $sub_pod_hash
# puts $sub_pod_path_hash

# 拷贝子模块文件夹
reg = Regexp.new(/\/$/)
@module_arr.each_with_index do |module_str, index| 
	if module_str != main_tp.name
		cur_url = $sub_pod_hash[module_str]
		nRoot = $sub_need_root_hash[module_str]
		if nRoot == 0
			to_path = cur_url
		else
			if reg =~ cur_url
				to_path = cur_url + module_str
			else 
				to_path = cur_url + '/' + module_str
			end
		end
		# puts to_path
		cur_from_path = $sub_pod_path_hash[module_str]
		traverse('sources/' + cur_from_path, to_path)
		delete_config_file(to_path)
	end
end 

# 删除主模块中的Aimfile
delete_config_file(main_tp.name)

# 添加依赖到podspec文件
podspec_path = "aim_project/{{cookiecutter.product_name}}/{{cookiecutter.product_name}}.podspec"
if FileTest.exist?(podspec_path)
	File.open(podspec_path, "a") do |file| 
		$dep_arr.each do |dep_name|
			file.puts("\ts.dependency " + dep_name + "\n")
		end
		file.puts :end
		file.close
	end
end

# 添加依赖到podfile文件
podfile_path = "aim_project/{{cookiecutter.product_name}}/App/Podfile"
if FileTest.exist?(podfile_path)
	File.open(podfile_path, "a") do |file| 
		$dep_arr.each do |dep_name|
			file.puts("\tpod " + dep_name + "\n")
		end
		file.puts :end
		file.close
	end
end