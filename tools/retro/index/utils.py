# coding=utf-8
# Copyright (c) 2022, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import glob
import os
import shutil
import torch

from megatron import get_args

# >>>
from lutil import pax
# <<<


def get_index_str():
    """Faiss notation for index structure."""
    args = get_args()
    return "OPQ%d_%d,IVF%d_HNSW%d,PQ%d" % (
        args.retro_pq_m,
        args.retro_ivf_dim,
        args.retro_nclusters,
        args.retro_hnsw_m,
        args.retro_pq_m,
    )


# # def get_base_index_workdir():
# # def get_top_index_workdir():
# def get_common_index_workdir():
#     args = get_args()
#     return os.path.join(args.retro_workdir, "index")
    

# # def get_index_workdir():
# # def get_sub_index_workdir():
# def get_current_index_workdir():
#     """Create sub-directory for this index."""
    
#     # Directory path.
#     args = get_args()
#     index_str = get_index_str()
#     index_dir_path = os.path.join(
#         get_common_index_workdir(),
#         args.retro_index_ty,
#         index_str,
#     )

#     # Make directory.
#     os.makedirs(index_dir_path, exist_ok = True)

#     return index_dir_path
def get_index_dir():
    """Create sub-directory for this index."""
    
    args = get_args()

    # Directory path.
    index_dir_path = os.path.join(
        args.retro_workdir,
        "index",
        args.retro_index_ty,
        get_index_str(),
    )

    # Make directory.
    os.makedirs(index_dir_path, exist_ok = True)

    return index_dir_path


# def get_embedding_dir(sub_dir):
#     embed_dir = os.path.join(get_index_dir(), "embed", sub_dir)
#     os.makedirs(embed_dir, exist_ok = True)
#     return embed_dir


# def get_merged_embedding_path(sub_dir):
#     return os.path.join(get_embedding_dir(sub_dir), "merged.hdf5")


# def get_embedding_paths(sub_dir):
#     paths = sorted(glob.glob(get_embedding_dir(sub_dir) + "/*.hdf5"))
#     merged_path = get_merged_embedding_path(sub_dir)
#     paths.remove(merged_path)
#     return paths


# def remove_embedding_dir(sub_dir):
#     if torch.distributed.get_rank() != 0:
#         return
#     dirname = get_embedding_dir(sub_dir)
#     shutil.rmtree(dirname)
def get_training_data_dir():
    return os.path.join(get_index_dir(), "training_data_tmp")


def get_training_data_block_dir():
    return os.path.join(get_training_data_dir(), "blocks")


def get_training_data_block_paths():
    return sorted(glob.glob(get_training_data_block_dir() + "/*.hdf5"))


def get_training_data_merged_path():
    return os.path.join(get_training_data_dir(), "merged.hdf5")


def remove_training_data():
    if torch.distributed.get_rank() != 0:
        return
    raise Exception("ready to delete?")
    shutil.rmtree(get_training_data_dir())
