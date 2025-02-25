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

#include "ppl/nn/engines/cuda/kernels/onnx/reshape_kernel.h"

#include "cudakernel/memory/reshape.h"

namespace ppl { namespace nn { namespace cuda {

ppl::common::RetCode ReshapeKernel::DoExecute(KernelExecContext* ctx) {
    auto input = ctx->GetInput<TensorImpl>(0);
    auto shape = ctx->GetInput<TensorImpl>(1);
    auto output = ctx->GetOutput<TensorImpl>(0);
    bool can_trans = input->GetType() == TENSORTYPE_NORMAL;
    ppl::common::RetCode status = ppl::common::RC_SUCCESS;

    for (auto iter = input->GetEdge()->CreateConsumerIter(); iter.IsValid(); iter.Forward()) {
        auto node_id = iter.Get();
        if (node_id != GetNode()->GetId() && node_id != shape->GetEdge()->GetProducer())
            can_trans = false;
    }

    if (can_trans) {
        output->TransferBufferFrom(input);
    } else {
        status = PPLCUDAReshapeForwardImp(GetStream(), input->GetShape(), input->GetBufferPtr(), output->GetShape(),
                                          output->GetBufferPtr());
    }

    return status;
}

}}} // namespace ppl::nn::cuda
