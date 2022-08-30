//
// Copyright (c) 2021 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package config

import (
	"fmt"
	"strings"
)

type ServiceConfig struct {
	Driver DriverConfig
}

type DriverConfig struct {
	PythonPath string
}

// UpdateFromRaw updates the service's full configuration from raw data received from
// the Service Provider.
func (sw *ServiceConfig) UpdateFromRaw(rawConfig interface{}) bool {
	configuration, ok := rawConfig.(*ServiceConfig)
	if !ok {
		return false
	}

	*sw = *configuration

	return true
}

func (d *DriverConfig) Validate() error {
	if !strings.HasPrefix(d.PythonPath, "/") {
		return fmt.Errorf("Driver.PythonPath isn't absolute.")
	}

	return nil
}
