-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing,
-- software distributed under the License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
-- KIND, either express or implied.  See the License for the
-- specific language governing permissions and limitations
-- under the License.

--------------------------------------------------------------------------------

local lua_path = os.getenv('LUAPATH')
if lua_path ~= nil then
    package.cpath = lua_path .. '/?.so'
end

--------------------------------------------------------------------------------

local pplnn = require("luappl.nn")
local pplcommon = require("luappl.common")

--------------------------------------------------------------------------------

local logging = {}

function logging.debug(msg)
    print("[debug]", msg)
end

function logging.info(msg)
    print("[info]", msg)
end

function logging.warning(msg)
    print("[warning]", msg)
end

function logging.error(msg)
    print("[error]", msg)
end

--------------------------------------------------------------------------------

function GenerateArgs()
    return {
        onnx_model = "tests/testdata/conv.onnx",
        use_x86 = true,
        use_cuda = false,
        save_data_dir = ".",
        save_inputs = false,
        save_outputs = false,
    }
end

--------------------------------------------------------------------------------

function RegisterEngines(args)
    local engines = {}
    if args.use_x86 then
        local x86_options = pplnn.x86.EngineOptions()
        local x86_engine = pplnn.x86.EngineFactory:Create(x86_options)
        table.insert(engines, x86_engine)
    end
    if args.use_cuda then
        local cuda_options = pplnn.cuda.EngineOptions()
        local cuda_engine = pplnn.cuda.EngineFactory:Create(cuda_options)
        table.insert(engines, cuda_engine)
    end
    return engines
end

--------------------------------------------------------------------------------

function SetRandomInputs(runtime)
    function GenerateRandomData(dims)
        local nr_element = 1
        for _, d in ipairs(dims) do
            nr_element = nr_element * d
        end

        local random_data = ""
        for i = 1, nr_element do
            random_data = random_data .. string.pack("f", math.random(-100, 100) / 100)
        end
        return random_data
    end

    for i = 1, runtime:GetInputCount() do
        local tensor = runtime:GetInputTensor(i - 1)
        local shape = tensor:GetShape()
        local data_type = shape:GetDataType()

        local dims = shape:GetDims()
        local in_data = GenerateRandomData(dims)
        local status = tensor:ConvertFromHost(in_data, dims, data_type)
        if status ~= pplcommon.RC_SUCCESS then
            logging.error("copy data to tensor[" .. tensor:GetName() .. "] failed: " ..
                          pplcommon.GetRetCodeStr(status))
            os.exit(-1)
        end
    end
end

--------------------------------------------------------------------------------

function CalcBytes(dims, item_size)
    local nbytes = item_size
    for _, d in ipairs(dims) do
        nbytes = nbytes * d
    end
    return nbytes
end

function GenDimsStr(dims)
    if next(dims) == nil then
        return ""
    end

    local content = tostring(dims[1])
    for i = 2, #dims do
        content = content .. "_" .. tostring(dims[i])
    end
    return content
end

--------------------------------------------------------------------------------

function WriteFileContent(filepath, content)
    local fd = io.open(filepath, "wb")
    fd:write(content)
    fd:close()
end

local g_data_type_str = {
    [pplcommon.DATATYPE_INT8] = "int8",
    [pplcommon.DATATYPE_INT16] = "int16",
    [pplcommon.DATATYPE_INT32] = "int32",
    [pplcommon.DATATYPE_INT64] = "int64",
    [pplcommon.DATATYPE_UINT8] = "uint8",
    [pplcommon.DATATYPE_UINT16] = "uint16",
    [pplcommon.DATATYPE_UINT32] = "uint32",
    [pplcommon.DATATYPE_UINT64] = "uint64",
    [pplcommon.DATATYPE_FLOAT16] = "fp16",
    [pplcommon.DATATYPE_FLOAT32] = "fp32",
    [pplcommon.DATATYPE_FLOAT64] = "fp64",
    [pplcommon.DATATYPE_BOOL] = "bool",
    [pplcommon.DATATYPE_UNKNOWN] = "unknown",
}

function SaveInputsOneByOne(save_data_dir, runtime)
    for i = 1, runtime:GetInputCount() do
        local tensor = runtime:GetInputTensor(i - 1)
        local shape = tensor:GetShape()
        local tensor_data = tensor:ConvertToHost()
        if tensor_data == nil then
            logging.error("copy data from tensor[" .. tensor:GetName() .. "] failed.")
            os.exit(-1)
        end

        WriteFileContent(save_data_dir .. "/pplnn_input_" .. tostring(i - 1) .. "_" ..
                         tensor:GetName() .. "-" .. GenDimsStr(shape:GetDims()) .. "-" ..
                         g_data_type_str[shape:GetDataType()] .. ".dat",
                         tensor_data)
    end
end

--------------------------------------------------------------------------------

function SaveOutputsOneByOne(save_data_dir, runtime)
    for i = 1, runtime:GetOutputCount() do
        local tensor = runtime:GetOutputTensor(i - 1)
        local tensor_data = tensor:ConvertToHost()
        if tensor_data == nil then
            logging.error("copy data from tensor[" .. tensor:GetName() .. "] failed.")
            os.exit(-1)
        end

        WriteFileContent(save_data_dir .. "/pplnn_output-" .. tensor:GetName() .. ".dat",
                         tensor_data)
    end
end

--------------------------------------------------------------------------------

function PrintInputOutputInfo(runtime)
    function Dims2Str(dims)
        local ret = ""
        for i = 1, #dims do
            ret = ret .. " " .. tostring(dims[i])
        end
        return ret
    end

    print("----- input info -----")
    for i = 1, runtime:GetInputCount() do
        local tensor = runtime:GetInputTensor(i - 1)
        local shape = tensor:GetShape()
        local dims = shape:GetDims()
        local data_type = shape:GetDataType()
        print("input[" .. tostring(i - 1) .. "]")
        print("    name: " .. tensor:GetName())
        print("    dim(s):" .. Dims2Str(dims))
        print("    data type: " .. pplcommon.GetDataTypeStr(data_type))
        print("    data format: " .. pplcommon.GetDataFormatStr(shape:GetDataFormat()))
        print("    byte(s) excluding padding: " .. tostring(CalcBytes(dims, pplcommon.GetSizeOfDataType(data_type))))
    end

    print("----- output info -----")
    for i = 1, runtime:GetOutputCount() do
        local tensor = runtime:GetOutputTensor(i - 1)
        local shape = tensor:GetShape()
        local dims = shape:GetDims()
        local data_type = shape:GetDataType()
        print("output[" .. tostring(i - 1) .. "]")
        print("    name: " .. tensor:GetName())
        print("    dim(s):" .. Dims2Str(dims))
        print("    type: " .. pplcommon.GetDataTypeStr(data_type))
        print("    format: " .. pplcommon.GetDataFormatStr(shape:GetDataFormat()))
        print("    byte(s) excluding padding: " .. tostring(CalcBytes(dims, pplcommon.GetSizeOfDataType(data_type))))
    end

    print("----------------------")
end

------------------------------------ main --------------------------------------

print("PPLNN version: [" .. pplnn.PPLNN_VERSION_MAJOR .. "." .. pplnn.PPLNN_VERSION_MINOR .. "." ..
      pplnn.PPLNN_VERSION_PATCH .. "], commit: [" .. pplnn.PPLNN_COMMIT_STR .. "]")

local args = GenerateArgs()

local runtime_builder = pplnn.onnx.RuntimeBuilderFactory:Create()
if runtime_builder == nil then
    logging.error("create OnnxRuntimeBuilder failed.")
    os.exit(-1)
end

local status = runtime_builder:LoadModelFromFile(args.onnx_model)
if status ~= pplcommon.RC_SUCCESS then
    logging.error("init OnnxRuntimeBuilder failed: " .. pplcommon.GetRetCodeStr(status))
    os.exit(-1)
end

local engines = RegisterEngines(args)
if next(engines) == nil then
    logging.info("no engine is specified.")
    os.exit(-1)
end

resources = pplnn.onnx.RuntimeBuilderResources()
resources.engines = engines
status = runtime_builder:SetResources(resources)
if status ~= pplcommon.RC_SUCCESS then
    logging.error("OnnxRuntimeBuilder set resources failed: " .. pplcommon.GetRetCodeStr(status))
    os.exit(-1)
end

status = runtime_builder:Preprocess()
if status ~= pplcommon.RC_SUCCESS then
    logging.error("OnnxRuntimeBuilder preprocess failed: " .. pplcommon.GetRetCodeStr(status))
    os.exit(-1)
end

local runtime = runtime_builder:CreateRuntime()
if runtime == nil then
    logging.error("create Runtime instance failed.")
    os.exit(-1)
end

SetRandomInputs(runtime)

if args.save_inputs then
    SaveInputsOneByOne(args.save_data_dir, runtime)
end

local status = runtime:Run()
if status ~= pplcommon.RC_SUCCESS then
    logging.error("Run() failed: " .. pplcommon.GetRetCodeStr(status))
    os.exit(-1)
end

PrintInputOutputInfo(runtime)

if args.save_outputs then
    SaveOutputsOneByOne(args.save_data_dir, runtime)
end

logging.info("Run ok")
