/*
 * Copyright © 2012-2014 Cask Data, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package co.cask.coopr.shell.command;

import co.cask.common.cli.Arguments;
import co.cask.common.cli.Command;
import co.cask.coopr.client.AdminClient;
import co.cask.coopr.shell.util.CliUtil;

import java.io.PrintStream;
import com.google.inject.Inject;

import static co.cask.coopr.shell.util.Constants.NAME_KEY;

/**
 * Gets the provider.
 */
public class GetProviderCommand implements Command {

  private final AdminClient adminClient;

  @Inject
  private GetProviderCommand(AdminClient adminClient) {
    this.adminClient = adminClient;
  }

  @Override
  public void execute(Arguments arguments, PrintStream printStream) throws Exception {
    String name = CliUtil.checkArgument(arguments.get(NAME_KEY));
    printStream.print(CliUtil.getPrettyJson(adminClient.getProvider(name)));
  }

  @Override
  public String getPattern() {
    return String.format("get provider <%s>", NAME_KEY);
  }

  @Override
  public String getDescription() {
    return "Gets the provider";
  }
}
