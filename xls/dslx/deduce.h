// Copyright 2020 The XLS Authors
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

#ifndef XLS_DSLX_DEDUCE_H_
#define XLS_DSLX_DEDUCE_H_

#include "xls/common/status/ret_check.h"
#include "xls/dslx/import_routines.h"
#include "xls/dslx/interp_bindings.h"

namespace xls::dslx {

// An entry on the "stack of functions currently being deduced".
struct FnStackEntry {
  std::string name;
  SymbolicBindings symbolic_bindings;
};

class DeduceCtx;  // Forward decl.

// Signature used for typechecking a single function within a module (this is
// generally used for typechecking parametric instantiations).
using TypecheckFunctionFn = std::function<absl::Status(Function*, DeduceCtx*)>;

// A single object that contains all the state/callbacks used in the
// typechecking process.
class DeduceCtx : public std::enable_shared_from_this<DeduceCtx> {
 public:
  DeduceCtx(const std::shared_ptr<TypeInfo>& type_info,
            const std::shared_ptr<Module>& module,
            TypecheckFunctionFn typecheck_function,
            TypecheckFn typecheck_module, ImportCache* import_cache)
      : type_info_(type_info),
        module_(module),
        typecheck_function_(std::move(typecheck_function)),
        typecheck_module_(std::move(typecheck_module)),
        import_cache_(import_cache) {}

  // Creates a new DeduceCtx reflecting the given type info and module.
  // Uses the same callbacks as this current context.
  //
  // Note that the resulting DeduceCtx has an empty fn_stack.
  DeduceCtx MakeCtx(const std::shared_ptr<TypeInfo>& new_type_info,
                    const std::shared_ptr<Module>& new_module) const {
    return DeduceCtx(new_type_info, new_module, typecheck_function_,
                     typecheck_module_, import_cache_);
  }

  std::vector<FnStackEntry>& fn_stack() { return fn_stack_; }
  const std::vector<FnStackEntry>& fn_stack() const { return fn_stack_; }

  const std::shared_ptr<Module>& module() const { return module_; }
  const std::shared_ptr<TypeInfo>& type_info() const { return type_info_; }

  // Creates a new TypeInfo that has the current type_info_ as its parent.
  void AddDerivedTypeInfo() {
    type_info_ = std::make_shared<TypeInfo>(module(), /*parent=*/type_info_);
  }

  // Pops the current type_info_ and sets the type_info_ to be the popped
  // value's parent (conceptually an inverse of AddDerivedTypeInfo()).
  absl::Status PopDerivedTypeInfo() {
    XLS_RET_CHECK(type_info_->parent() != nullptr);
    type_info_ = type_info_->parent();
    return absl::OkStatus();
  }

  // Adds an entry to the stack of functions currently being deduced.
  void AddFnStackEntry(FnStackEntry entry) {
    fn_stack_.push_back(std::move(entry));
  }

  // Pops an entry from the stack of functions currently being deduced and
  // returns it, conceptually the inverse of AddFnStackEntry().
  absl::optional<FnStackEntry> PopFnStackEntry() {
    if (fn_stack_.empty()) {
      return absl::nullopt;
    }
    FnStackEntry result = fn_stack_.back();
    fn_stack_.pop_back();
    return result;
  }

  const TypecheckFn& typecheck_module() const { return typecheck_module_; }
  const TypecheckFunctionFn& typecheck_function() const {
    return typecheck_function_;
  }

  ImportCache* import_cache() const { return import_cache_; }

 private:
  // Maps AST nodes to their deduced types.
  std::shared_ptr<TypeInfo> type_info_;

  // The (entry point) module we are typechecking.
  std::shared_ptr<Module> module_;

  // -- Callbacks

  // Typechecks parametric functions that are not in this module.
  TypecheckFunctionFn typecheck_function_;

  // Callback used to typecheck a module and get its type info (e.g. on import).
  TypecheckFn typecheck_module_;

  // Cache used for imported modules, may be nullptr.
  ImportCache* import_cache_;

  // -- Metadata

  // Keeps track of the function we're currently typechecking and the symbolic
  // bindings that deduction is running on.
  std::vector<FnStackEntry> fn_stack_;
};

}  // namespace xls::dslx

#endif  // XLS_DSLX_DEDUCE_H_