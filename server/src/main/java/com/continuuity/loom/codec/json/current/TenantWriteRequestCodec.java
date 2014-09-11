/*
 * Copyright © 2012-2014 Cask Data, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.continuuity.loom.codec.json.current;

import com.continuuity.loom.http.request.TenantWriteRequest;
import com.continuuity.loom.spec.TenantSpecification;
import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;

import java.lang.reflect.Type;

/**
 * Codec for deserializing a {@link com.continuuity.loom.http.request.TenantWriteRequest},
 * used so some validation is done on required fields.
 */
public class TenantWriteRequestCodec implements JsonDeserializer<TenantWriteRequest> {

  @Override
  public TenantWriteRequest deserialize(JsonElement json, Type type, JsonDeserializationContext context)
    throws JsonParseException {
    JsonObject jsonObj = json.getAsJsonObject();

    TenantSpecification tenantSpec = context.deserialize(jsonObj.get("tenant"), TenantSpecification.class);
    Boolean bootstrap = context.deserialize(jsonObj.get("bootstrap"), Boolean.class);

    return new TenantWriteRequest(tenantSpec, bootstrap);
  }
}
