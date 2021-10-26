// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#include "ppl/nn/models/onnx/parsers/onnx/parse_pad_param.h"
#include "ppl/nn/common/logger.h"
#include "ppl/nn/models/onnx/utils.h"
using namespace std;

namespace ppl { namespace nn { namespace onnx {

ppl::common::RetCode ParsePadParam(const ::onnx::NodeProto& pb_node, const map<string, uint64_t>&, void* arg, ir::Node*,
                                   ir::GraphTopo*) {
    auto param = static_cast<ppl::nn::common::PadParam*>(arg);
    std::string mode = utils::GetNodeAttrByKey<std::string>(pb_node, "mode", "constant");
    if (mode == "constant") {
        param->mode = ppl::nn::common::PadParam::PAD_MODE_CONSTANT;
    } else if (mode == "reflect") {
        param->mode = ppl::nn::common::PadParam::PAD_MODE_REFLECT;
    } else if (mode == "edge") {
        param->mode = ppl::nn::common::PadParam::PAD_MODE_EDGE;
    } else {
        LOG(ERROR) << "Invalid pad mode " << mode << ".";
        return ppl::common::RC_INVALID_VALUE;
    }
    return ppl::common::RC_SUCCESS;
}

}}} // namespace ppl::nn::onnx