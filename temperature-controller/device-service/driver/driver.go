// -*- Mode: Go; indent-tabs-mode: t -*-
//
// Copyright (C) 2018 Canonical Ltd
// Copyright (C) 2018-2022 IOTech Ltd
//
// SPDX-License-Identifier: Apache-2.0

// This package provides a simple example implementation of
// ProtocolDriver interface.
//
package driver

import (
	"encoding/json"
	"errors"
	"fmt"
	"os/exec"
	"strings"

	"github.com/edgexfoundry/go-mod-core-contracts/v2/clients/logger"
	"github.com/edgexfoundry/go-mod-core-contracts/v2/models"

	sdkModels "github.com/edgexfoundry/device-sdk-go/v2/pkg/models"
	"github.com/edgexfoundry/device-sdk-go/v2/pkg/service"
	"github.com/edgexfoundry/device-simple/config"
)

type Driver struct {
	lc            logger.LoggingClient
	fanState      bool
	serviceConfig *config.ServiceConfig
}

// Initialize performs protocol-specific initialization for the device
// service.
func (s *Driver) Initialize(lc logger.LoggingClient, asyncCh chan<- *sdkModels.AsyncValues, deviceCh chan<- []sdkModels.DiscoveredDevice) error {
	s.lc = lc
	s.serviceConfig = &config.ServiceConfig{}

	ds := service.RunningService()

	if err := ds.LoadCustomConfig(s.serviceConfig, "Driver"); err != nil {
		return fmt.Errorf("unable to load 'Driver' config: %s", err.Error())
	}

	lc.Infof("Driver config is: %v", s.serviceConfig.Driver)

	if err := s.serviceConfig.Driver.Validate(); err != nil {
		return fmt.Errorf("'Driver' config validation failed: %s", err.Error())
	}

	out, err := exec.Command(s.serviceConfig.Driver.PythonPath, "--version").CombinedOutput()
	if err != nil {
		return fmt.Errorf("unable to get python version: %s: %s", err, out)
	}
	if !strings.HasPrefix(string(out), "Python 3") {
		return fmt.Errorf("expected Python 3, got: %s", out)
	}

	return nil
}

type bme680 struct {
	Temperature float32
	Humidity    float32
	// Pressure    float32
	// Gas         uint32
}

// HandleReadCommands triggers a protocol Read operation for the specified device.
func (s *Driver) HandleReadCommands(deviceName string, protocols map[string]models.ProtocolProperties, reqs []sdkModels.CommandRequest) (res []*sdkModels.CommandValue, err error) {
	s.lc.Debugf("Driver.HandleReadCommands: protocols: %v resource: %v attributes: %v", protocols, reqs[0].DeviceResourceName, reqs[0].Attributes)

	// handle device command
	if len(reqs) == 2 &&
		reqs[0].DeviceResourceName == "Temperature" &&
		reqs[1].DeviceResourceName == "Humidity" {

		cmd := exec.Cmd{
			Path: s.serviceConfig.Driver.PythonPath,
			Env: []string{
				"BLINKA_FT232H=true",
			},
		}
		cmd.Args = append(cmd.Args, cmd.Path,
			"ft232h-bme680.py", // script path
			"-i2c", protocols["i2c"]["Address"])

		b, err := cmd.CombinedOutput()
		if err != nil {
			return nil, fmt.Errorf("%s: %s", err, b)
		}
		s.lc.Debugf("Script output: %s\n", b)
		var data bme680
		err = json.Unmarshal(b, &data)
		if err != nil {
			return nil, err
		}

		res = make([]*sdkModels.CommandValue, len(reqs))
		for i, r := range reqs {
			var value any
			switch r.DeviceResourceName {
			case "Temperature":
				value = data.Temperature
			case "Humidity":
				value = data.Humidity
			}

			cv, err := sdkModels.NewCommandValue(r.DeviceResourceName, r.Type, value)
			if err != nil {
				return nil, err
			}
			s.lc.Debugf("Reading %s: %s", r.DeviceResourceName, cv)
			res[i] = cv
		}
	} else {
		return nil, fmt.Errorf("bad request")
	}

	return
}

// HandleWriteCommands passes a slice of CommandRequest struct each representing
// a ResourceOperation for a specific device resource.
// Since the commands are actuation commands, params provide parameters for the individual
// command.
func (s *Driver) HandleWriteCommands(deviceName string, protocols map[string]models.ProtocolProperties, reqs []sdkModels.CommandRequest,
	params []*sdkModels.CommandValue) error {
	var err error

	fmt.Printf("reqs: %v\n", reqs)
	fmt.Printf("protocols: %v\n", protocols)

	for i, r := range reqs {
		s.lc.Debugf("Driver.HandleWriteCommands: protocols: %v, resource: %v, parameters: %v, attributes: %v", protocols, reqs[i].DeviceResourceName, params[i], reqs[i].Attributes)
		switch r.DeviceResourceName {
		case "State":
			if s.fanState, err = params[i].BoolValue(); err != nil {
				err := fmt.Errorf("Driver.HandleWriteCommands; the data type of parameter should be Boolean, parameter: %s", params[0].String())
				return err
			}
			fmt.Printf("Fan state: %v\n", s.fanState)

			cmd := exec.Cmd{
				Path: s.serviceConfig.Driver.PythonPath,
				Env: []string{
					"BLINKA_FT232H=true",
				},
			}
			cmd.Args = append(cmd.Args, cmd.Path,
				"ft232h-gpio.py", // script path
				"-pin", protocols["gpio"]["Pin"],
				"-value", fmt.Sprint(s.fanState))

			b, err := cmd.CombinedOutput()
			if err != nil {
				return fmt.Errorf("%s: %s", err, b)
			}
			s.lc.Debugf("Script output: %s\n", b)
		}
	}

	return nil
}

// Stop the protocol-specific DS code to shutdown gracefully, or
// if the force parameter is 'true', immediately. The driver is responsible
// for closing any in-use channels, including the channel used to send async
// readings (if supported).
func (s *Driver) Stop(force bool) error {
	// Then Logging Client might not be initialized
	if s.lc != nil {
		s.lc.Debugf("Driver.Stop called: force=%v", force)
	}
	return nil
}

// AddDevice is a callback function that is invoked
// when a new Device associated with this Device Service is added
func (s *Driver) AddDevice(deviceName string, protocols map[string]models.ProtocolProperties, adminState models.AdminState) error {
	s.lc.Debugf("a new Device is added: %s", deviceName)
	return nil
}

// UpdateDevice is a callback function that is invoked
// when a Device associated with this Device Service is updated
func (s *Driver) UpdateDevice(deviceName string, protocols map[string]models.ProtocolProperties, adminState models.AdminState) error {
	s.lc.Debugf("Device %s is updated", deviceName)
	return nil
}

// RemoveDevice is a callback function that is invoked
// when a Device associated with this Device Service is removed
func (s *Driver) RemoveDevice(deviceName string, protocols map[string]models.ProtocolProperties) error {
	s.lc.Debugf("Device %s is removed", deviceName)
	return nil
}

// Discover triggers protocol specific device discovery, which is an asynchronous operation.
// Devices found as part of this discovery operation are written to the channel devices.
func (s *Driver) Discover() {}

func (s *Driver) ValidateDevice(device models.Device) error {
	if device.ProfileName == "BME680" {
		i2c, ok := device.Protocols["i2c"]
		if !ok {
			return errors.New("missing 'i2c' protocol")
		}

		addr, ok := i2c["Address"]
		if !ok {
			return errors.New("missing 'i2c.Address' value")
		} else if addr == "" {
			return errors.New("'i2c.address' must not empty")
		}
	}

	if device.ProfileName == "FanController" {
		gpio, ok := device.Protocols["gpio"]
		if !ok {
			return errors.New("missing 'gpio' protocol")
		}

		pin, ok := gpio["Pin"]
		if !ok {
			return errors.New("missing 'gpio.pin' value")
		} else if pin == "" {
			return errors.New("'gpio.pin' must not empty")
		}
	}

	return nil
}
