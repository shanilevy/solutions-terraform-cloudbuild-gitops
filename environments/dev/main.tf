# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  env = "dev"
}

provider "google" {
  project = var.project
  credentials = file("gs://dataops-prefix-eu-dataops-bucket-1234/bq-key.json")
}

module "vpc" {
  source  = "../../modules/vpc"
  project = var.project
  env     = local.env
}

module "http_server" {
  source  = "../../modules/http_server"
  project = var.project
  subnet  = module.vpc.subnet
}

module "firewall" {
  source  = "../../modules/firewall"
  project = var.project
  subnet  = module.vpc.subnet
}
  
module "bigquery" {
  source                     = "terraform-google-modules/bigquery/google"
  version                    = "4.5.0"
  dataset_id                 = "dwh"
  dataset_name               = "dwh"
  description                = "Our main data warehouse located in the US"
  project_id                 = var.project
  location                   = "US"
  delete_contents_on_destroy = true
  tables = [
    {
      table_id           = "wikipedia_pageviews_2021",
      schema             = "schemas/pageviews_2021.schema.json",
      time_partitioning  = null,
      range_partitioning = null,
      expiration_time    = 2524604400000, # 2050/01/01
      clustering = [ "wiki", "title" ],
      labels = {
        env      = "devops"
        billable = "true"
        owner    = "joedoe"
      },
    }
  ]
  dataset_labels = {
    env      = "dev"
    billable = "true"
    owner    = "janesmith"
  }
}
  
module "gcs_buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "1.7.2"

  names       = ["dataops-bucket-1234"]
  prefix = "dataops-prefix"
  project_id = var.project
  #location   = "us-east1"

  set_admin_roles = true
  versioning = {
    first = true
  }
}
